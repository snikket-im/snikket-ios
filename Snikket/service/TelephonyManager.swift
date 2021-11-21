//
//  TelephonyManager.swift
//  Snikket
//
//  Created by Muhammad Khalid on 09/10/2021.
//  Copyright © 2021 Snikket. All rights reserved.
//

import TigaseSwift
import Foundation
import UIKit

class TelephonyManager: XmppServiceEventHandler {
    var events: [Event] = [RosterModule.ItemUpdatedEvent.TYPE]
    
    func handle(event: Event) {
        switch event {
        case let e as RosterModule.ItemUpdatedEvent:
            isTelephonyProvider(event: e)
        default:
            break
        }
    }
    
    private func isTelephonyProvider(event: RosterModule.ItemUpdatedEvent) {
        
        guard let account = event.sessionObject.userBareJid, let rosterItem = event.rosterItem else { return }
        
        // No Telephony Currently Configured
        guard AccountSettings.telephonyProvider(account).getString() == nil else { return }
        
        // No Local Part
        guard rosterItem.jid.localPart == nil else { return }
        
        // Subscribed to User Presence
        guard rosterItem.subscription.isFrom else { return }
        
        // Advertises Identity of Category "gateway" and Type "pstn"
        verifyService(account: account, jid: rosterItem.jid) { [weak self] success in
            if success {
                self?.enableProviderAlert(account: account, jid: rosterItem.jid)
            }
        }
    }
    
    func verifyService(account: BareJID, jid: JID, completion: @escaping (Bool)->Void) {
        let client = XmppService.instance.getClient(for: account)
        
        if let module: DiscoveryModule = client?.modulesManager.getModule(DiscoveryModule.ID) {
            module.getInfo(for: jid, node: nil, completionHandler: { result in
                switch result {
                case .success(_, let identities, _):
                    for identity in identities {
                        if identity.category.lowercased() == "gateway", identity.type.lowercased() == "pstn" {
                            completion(true)
                        }
                    }
                case .failure(let errorCondition, _):
                    print(errorCondition)
                }
            })
        }
    }
    
    func enableProviderAlert(account: BareJID, jid: JID) {
        
        let alert = UIAlertController(title: NSLocalizedString("Enable telephony provider?", comment: ""), message: String.localizedStringWithFormat(NSLocalizedString("Would you like to use %@ as the default provider for outgoing SMS and calls from %@?", comment: ""), jid.stringValue, account.stringValue), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String.localizedStringWithFormat(NSLocalizedString("Enable %@", comment: ""), jid.stringValue), style: .default, handler: {(action) in
            AccountSettings.telephonyProvider(account).set(string: jid.stringValue)
        }))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .destructive, handler: nil))
        var topController = UIApplication.shared.keyWindow?.rootViewController
        while (topController?.presentedViewController != nil) {
            topController = topController?.presentedViewController
        }
        DispatchQueue.main.async {
            topController?.present(alert, animated: true, completion: nil)
        }
        
    }
    
}
