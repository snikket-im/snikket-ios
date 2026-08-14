//
// OpenSSLSocketTLSProcessor.swift
//
// TLS record processor for TigaseSwift 2.1's STARTTLS connector. The socket
// remains owned by TigaseSwift; OpenSSL handles the TLS 1.3 handshake and
// encryption through memory BIOs.
//

import Foundation
import OpenSSL
import TigaseSwift

public final class OpenSSLSocketTLSProcessor: SocketConnectorTLSProcessor {
    public weak var delegate: SocketConnectorTLSProcessorDelegate?

    // TLS 1.2 suites from the TLSRef Intermediate profile. TLS 1.3 uses
    // OpenSSL's separate default cipher-suite list.
    private static let tls12CipherSuites =
        "ECDHE-ECDSA-AES128-GCM-SHA256:"
        + "ECDHE-RSA-AES128-GCM-SHA256:"
        + "ECDHE-ECDSA-AES256-GCM-SHA384:"
        + "ECDHE-RSA-AES256-GCM-SHA384:"
        + "ECDHE-ECDSA-CHACHA20-POLY1305:"
        + "ECDHE-RSA-CHACHA20-POLY1305"

    private enum State {
        case ready
        case handshaking
        case active
        case closed
    }

    private struct PendingWrite {
        let data: Data
        let completionHandler: (() -> Void)?
    }

    private enum ProcessorError: Error {
        case initializationFailed
        case inputFailed
        case handshakeFailed(Int32)
        case certificateUnavailable
        case certificateRejected
        case readFailed(Int32)
        case writeFailed(Int32)
    }

    private let context: OpaquePointer
    private let ssl: OpaquePointer
    private let readBIO: OpaquePointer
    private let writeBIO: OpaquePointer
    private var state: State = .ready
    private var pendingWrites: [PendingWrite] = []

    public init?() {
        guard let context = SSL_CTX_new(TLS_client_method()) else {
            return nil
        }

        // Retain TLS 1.2 compatibility for older self-hosted Snikket servers,
        // while allowing OpenSSL to negotiate TLS 1.3 with newer servers.
        guard SSL_CTX_ctrl(context, SSL_CTRL_SET_MIN_PROTO_VERSION,
                           Int(TLS1_2_VERSION), nil) == 1 else {
            SSL_CTX_free(context)
            return nil
        }

        let cipherListConfigured = Self.tls12CipherSuites.withCString {
            SSL_CTX_set_cipher_list(context, $0)
        }
        guard cipherListConfigured == 1 else {
            SSL_CTX_free(context)
            return nil
        }

        guard let ssl = SSL_new(context) else {
            SSL_CTX_free(context)
            return nil
        }
        guard let readBIO = BIO_new(BIO_s_mem()) else {
            SSL_free(ssl)
            SSL_CTX_free(context)
            return nil
        }
        guard let writeBIO = BIO_new(BIO_s_mem()) else {
            BIO_free(readBIO)
            SSL_free(ssl)
            SSL_CTX_free(context)
            return nil
        }

        self.context = context
        self.ssl = ssl
        self.readBIO = readBIO
        self.writeBIO = writeBIO

        SSL_CTX_ctrl(context, SSL_CTRL_SET_SESS_CACHE_MODE,
                     Int(SSL_SESS_CACHE_CLIENT | SSL_SESS_CACHE_NO_INTERNAL_STORE), nil)
        SSL_set_bio(ssl, readBIO, writeBIO)
        SSL_set_connect_state(ssl)
    }

    deinit {
        SSL_free(ssl)
        SSL_CTX_free(context)
    }

    public func start(serverName: String) {
        guard state == .ready else { return }

        _ = serverName.withCString {
            SSL_ctrl(ssl, SSL_CTRL_SET_TLSEXT_HOSTNAME,
                     Int(TLSEXT_NAMETYPE_host_name),
                     UnsafeMutableRawPointer(mutating: $0))
        }

        var alpn = Self.alpnWireFormat(["xmpp-client"])
        _ = SSL_set_alpn_protos(ssl, &alpn, UInt32(alpn.count))

        state = .handshaking
        continueHandshake()
    }

    public func read(encryptedData: Data) {
        guard state != .closed, !encryptedData.isEmpty else { return }

        let count = encryptedData.withUnsafeBytes { bytes -> Int32 in
            guard let address = bytes.baseAddress else { return 0 }
            return BIO_write(readBIO, address, Int32(bytes.count))
        }
        guard count == Int32(encryptedData.count) else {
            fail(.inputFailed)
            return
        }

        switch state {
        case .handshaking:
            continueHandshake()
        case .active:
            readPlaintext()
        case .ready, .closed:
            break
        }
    }

    public func write(plainData: Data, completionHandler: (() -> Void)?) {
        guard state != .closed else { return }
        guard !plainData.isEmpty else {
            completionHandler?()
            return
        }

        pendingWrites.append(PendingWrite(data: plainData, completionHandler: completionHandler))
        if state == .active {
            encryptPendingWrites()
        }
    }

    public func close() {
        state = .closed
        pendingWrites.removeAll()
        delegate = nil
    }

    private func continueHandshake() {
        let result = SSL_do_handshake(ssl)
        if result == 1 {
            guard let trust = peerTrust() else {
                fail(.certificateUnavailable)
                return
            }
            guard delegate?.tlsProcessor(self, shouldTrust: trust) == true else {
                fail(.certificateRejected)
                return
            }

            state = .active
            #if DEBUG
            print("OpenSSL STARTTLS negotiated", String(cString: SSL_get_version(ssl)))
            #endif
            drainEncryptedOutput(completionHandler: nil)
            readPlaintext()
            encryptPendingWrites()
            return
        }

        let error = SSL_get_error(ssl, result)
        switch error {
        case SSL_ERROR_WANT_READ, SSL_ERROR_WANT_WRITE:
            drainEncryptedOutput(completionHandler: nil)
        default:
            drainEncryptedOutput(completionHandler: nil)
            fail(.handshakeFailed(error))
        }
    }

    private func readPlaintext() {
        while state == .active {
            var buffer = [UInt8](repeating: 0, count: 4096)
            let count = SSL_read(ssl, &buffer, Int32(buffer.count))
            if count > 0 {
                delegate?.tlsProcessor(self, didRead: Data(buffer.prefix(Int(count))))
                continue
            }

            let error = SSL_get_error(ssl, count)
            switch error {
            case SSL_ERROR_WANT_READ:
                return
            case SSL_ERROR_WANT_WRITE:
                drainEncryptedOutput(completionHandler: nil)
                return
            case SSL_ERROR_ZERO_RETURN:
                closeCleanly()
                return
            default:
                drainEncryptedOutput(completionHandler: nil)
                fail(.readFailed(error))
                return
            }
        }
    }

    private func closeCleanly() {
        pendingWrites.removeAll()

        // The peer sent close_notify. Complete the bidirectional TLS shutdown
        // and close the owning socket only after its response has been written.
        _ = SSL_shutdown(ssl)
        drainEncryptedOutput { [weak self] in
            guard let self = self, self.state != .closed else { return }
            self.state = .closed
            self.delegate?.tlsProcessorDidClose(self)
        }
    }

    private func encryptPendingWrites() {
        while state == .active, !pendingWrites.isEmpty {
            let entry = pendingWrites.removeFirst()
            let count = entry.data.withUnsafeBytes { bytes -> Int32 in
                guard let address = bytes.baseAddress else { return 0 }
                return SSL_write(ssl, address, Int32(bytes.count))
            }

            if count > 0 {
                drainEncryptedOutput(completionHandler: entry.completionHandler)
                continue
            }

            let error = SSL_get_error(ssl, count)
            switch error {
            case SSL_ERROR_WANT_READ, SSL_ERROR_WANT_WRITE:
                pendingWrites.insert(entry, at: 0)
                drainEncryptedOutput(completionHandler: nil)
                return
            default:
                fail(.writeFailed(error))
                return
            }
        }
    }

    private func drainEncryptedOutput(completionHandler: (() -> Void)?) {
        var output = Data()
        while true {
            let pending = Int(BIO_ctrl_pending(writeBIO))
            guard pending > 0 else { break }

            var buffer = [UInt8](repeating: 0, count: pending)
            let count = BIO_read(writeBIO, &buffer, Int32(buffer.count))
            guard count > 0 else { break }
            output.append(contentsOf: buffer.prefix(Int(count)))
        }

        if output.isEmpty {
            completionHandler?()
        } else {
            delegate?.tlsProcessor(self, didWrite: output, completionHandler: completionHandler)
        }
    }

    private func peerTrust() -> SecTrust? {
        guard let chain = SSL_get_peer_cert_chain(ssl) else { return nil }

        var certificates: [SecCertificate] = []
        let count = OPENSSL_sk_num(chain)
        for index in 0..<count {
            guard let value = OPENSSL_sk_value(chain, index) else { continue }
            if let converted = secCertificate(from: OpaquePointer(value)) {
                certificates.append(converted)
            }
        }
        guard !certificates.isEmpty else { return nil }

        var trust: SecTrust?
        guard SecTrustCreateWithCertificates(certificates as CFArray,
                                             SecPolicyCreateBasicX509(), &trust) == errSecSuccess else {
            return nil
        }
        return trust
    }

    private func secCertificate(from certificate: OpaquePointer) -> SecCertificate? {
        let size = i2d_X509(certificate, nil)
        guard size > 0 else { return nil }

        var data = Data(count: Int(size))
        let written = data.withUnsafeMutableBytes { bytes -> Int32 in
            var address = bytes.bindMemory(to: UInt8.self).baseAddress
            return i2d_X509(certificate, &address)
        }
        guard written == size else { return nil }
        return SecCertificateCreateWithData(nil, data as CFData)
    }

    private func fail(_ error: ProcessorError) {
        guard state != .closed else { return }
        state = .closed
        pendingWrites.removeAll()
        delegate?.tlsProcessor(self, didFail: error)
    }

    private static func alpnWireFormat(_ protocols: [String]) -> [UInt8] {
        protocols.reduce(into: []) { bytes, value in
            let protocolBytes = Array(value.utf8)
            bytes.append(UInt8(protocolBytes.count))
            bytes.append(contentsOf: protocolBytes)
        }
    }
}
