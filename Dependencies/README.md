# TigaseSwift TLS patch

Snikket uses TigaseSwift 2.1.3. Its CFStream TLS code cannot connect to an
XMPP server that requires TLS 1.3.

`patches/tigase-swift-2.1.3-starttls-tls13.patch` lets the socket connector use
an app-provided TLS processor. It also corrects certificate hostname
validation. Snikket provides the processor with its bundled OpenSSL library.

The shared Xcode schemes run `Dependencies/apply-tigase-tls13-patch.sh` before
a build.

To apply the patch manually after package resolution, run:

```sh
Dependencies/apply-tigase-tls13-patch.sh /path/to/DerivedData
```

When we update TigaseSwift, we must rebase or remove the patch.
