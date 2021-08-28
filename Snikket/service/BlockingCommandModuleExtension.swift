//
//  BlockingCommandModuleExtension.swift
//  Snikket
//
//  Created by Khalid Khan on 8/26/21.
//  Copyright © 2021 Snikket. All rights reserved.
//

import TigaseSwift
import Foundation

extension BlockingCommandModule {
    func blockAndReport(jids: [JID], completionHandler: @escaping (Result<Void,ErrorCondition>)->Void) {
        guard !jids.isEmpty, let jid = jids.first else {
            completionHandler(.success(Void()))
            return
        }
        
        let iq = Iq()
        iq.type = StanzaType.set
        let block = Element(name: "block", xmlns: BlockingCommandModule.BC_XMLNS)
        let item = Element(name: "item",attributes: ["jid" : jid.stringValue])
        let report = Element(name: "report", attributes: ["xmlns":"urn:xmpp:reporting:1","reason":"urn:xmpp:reporting:abuse"])
        item.addChild(report)
        block.addChild(item)
        iq.addChild(block)
        context.writer?.write(iq, callback: { result in
            if (result?.type ?? .error) == .error {
                completionHandler(.failure(result?.errorCondition ?? ErrorCondition.remote_server_timeout))
            } else {
                completionHandler(.success(Void()))
            }
        })
    }
}
