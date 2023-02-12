//
//  PEPDisplayNameModule.swift
//  Snikket
//
//  Created by Khalid Khan on 8/24/21.
//  Copyright © 2021 Snikket. All rights reserved.
//

import Foundation
import TigaseSwift

class PEPDisplayNameModule: AbstractPEPModule {
    
    public static let ID = "NICKNAME"
    
    public static let XMLNS = "http://jabber.org/protocol/nick"
    
    public static let PUBSUB_XMLNS = "http://jabber.org/protocol/pubsub";
    public static let PUBSUB_EVENT_XMLNS = PUBSUB_XMLNS + "#event";
    
    public static let FEATURES: [String] = [XMLNS + "+notify"]
    
    var id = ID
    
    var criteria = Criteria.empty();
    
    var features: [String] = FEATURES
    
    func process(stanza: Stanza) throws {
        throw ErrorCondition.bad_request
    }
    
    var context: Context!{
        didSet {
            if oldValue != nil {
                oldValue.eventBus.unregister(handler: self, for: PubSubModule.NotificationReceivedEvent.TYPE);
            }
            if context != nil {
                context.eventBus.register(handler: self, for: PubSubModule.NotificationReceivedEvent.TYPE);
            }
        }
    }
    
    func publishNick(nick: String, userJID: JID, completion: @escaping (Bool)->Void) {
        guard let pubsubModule: PubSubModule = context.modulesManager.getModule(PubSubModule.ID) else {
            print("Required PubSubModule is not registered!")
            return
        }
        
        let payload = Element(name: "nick", cdata: nick, xmlns: PEPDisplayNameModule.XMLNS)
        
        pubsubModule.publishItem(at: nil, to: PEPDisplayNameModule.XMLNS, payload: payload) { responseStanza in
            switch responseStanza {
            case .success(response: _, node: _, itemId: _):
                completion(true)
            case .failure(errorCondition: _, pubSubErrorCondition: _, response: _):
                completion(false)
            }
        }
    }
    
    func retrieveNick(from jid: BareJID, itemId: String? = nil, completion: @escaping (String?)->Void) {
        guard let pubsubModule: PubSubModule = context.modulesManager.getModule(PubSubModule.ID) else {
            print("Required PubSubModule is not registered!")
            return
        }
        
        pubsubModule.retrieveItems(from: jid, for: PEPDisplayNameModule.XMLNS) { responseStanza in
            switch responseStanza {
            case .success(_, _, let items,_):
                if let nick = items.first?.payload?.value {
                    completion(nick)
                } else { completion(nil) }
                
            case .failure(errorCondition: _, pubsubErrorCondition: _, response: _):
                completion(nil)
            }
            
        }
        
    }
    
    func handle(event: Event) {
        switch event {
        case let nre as PubSubModule.NotificationReceivedEvent:
            guard nre.nodeName == PEPDisplayNameModule.XMLNS, let from = nre.message.from else { return }
            
            let nick = nre.payload?.value
            context.eventBus.fire(NickChangedEvent(sessionObject: nre.sessionObject, jid: from, itemId: nre.itemId, nick: nick))
        default:
            break;
        }
    }
    
    static func getDisplayName(account: BareJID, for jid: BareJID) -> String {
        guard let client = XmppService.instance.getClient(forJid: account) else { return "" }
        
        let rosterModule: RosterModule? = client.modulesManager.getModule(RosterModule.ID);
        let rosterItem = rosterModule?.rosterStore.get(for: JID(jid))
        var name = rosterItem?.name ?? DBRosterStore.instance.getNickname(jid: jid.stringValue)
        name = name == nil ? (jid.localPart == nil ? jid.domain : jid.localPart) : name
        return name ?? ""
    }
    
    public init() { }
    
    class NickChangedEvent: Event {
        public static let TYPE = NickChangedEvent()
        
        public let type = "PEPNickChanged"
        
        public let sessionObject: SessionObject!
        public let jid: JID!
        public let itemId: String?
        public let nick: String?
        
        init() {
            self.sessionObject = nil
            self.jid = nil
            self.itemId = nil
            self.nick = nil
        }
        
        init(sessionObject: SessionObject, jid: JID, itemId: String?, nick: String?) {
            self.sessionObject = sessionObject
            self.jid = jid
            self.itemId = itemId
            self.nick = nick ?? ""
        }
    }
    
}
class NickChangeEventHandler: XmppServiceEventHandler {
    public static let NICK_CHANGED = Notification.Name("NICK_CHANGED")
    
    var events: [Event] = [PEPDisplayNameModule.NickChangedEvent.TYPE]
    
    func handle(event: Event) {
        guard let event = event as? PEPDisplayNameModule.NickChangedEvent, let account = event.sessionObject.userBareJid, let jid = event.jid, let nick = event.nick else { return }
        
        DBRosterStore.instance.updateNick(jid: jid.stringValue, nick: nick)
        
        NotificationCenter.default.post(name: NickChangeEventHandler.NICK_CHANGED, object: self, userInfo: ["account":account, "jid": BareJID(jid)])
        
//        if let nickname = DBRosterStore.instance.getNickname(jid: jid.stringValue), nickname != nick, let account = event.sessionObject.userBareJid {
//            NotificationCenter.default.post(name: NickChangeEventHandler.NICK_CHANGED, object: self, userInfo: ["account":account,"jid": BareJID(jid)])
//        }
        
        
        
    }
}
