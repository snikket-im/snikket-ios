//
//  DBLastMessageSyncStore.swift
//  Snikket
//
//  Created by Hammad Ashraf on 08/09/2021.
//  Copyright © 2021 Snikket. All rights reserved.
//

import Foundation
import TigaseSwift
import Shared

// Table last_message_sync :-
// account      TEXT
// jid          TEXT
// received_id  TEXT
// read_id      TEXT

class DBLastMessageSyncStore {
    
    static let instance = DBLastMessageSyncStore()
    
    fileprivate let dispatcher: QueueDispatcher;
    
    private let insertLastMessage: DBStatement
    private let getLastMessage: DBStatement
    private let updateLastMessage: DBStatement
    
    private init() {
        insertLastMessage = try! DBConnection.main.prepareStatement("INSERT INTO last_message_sync (account, jid, received_id, read_id) VALUES (:account, :jid, :received_id, :read_id)")
        
        updateLastMessage = try! DBConnection.main.prepareStatement("UPDATE last_message_sync SET received_id = :received_id, read_id = :read_id WHERE account = :account AND jid = :jid")
        
        getLastMessage = try! DBConnection.main.prepareStatement("SELECT account, jid, received_id, read_id FROM last_message_sync WHERE account = :account AND jid = :jid")
        
        dispatcher = QueueDispatcher(label: "last_message_sync")
    }
    
    func insertmessage(account: BareJID, jid: BareJID, receivedId: String?, readId: String?) {
        let params: [String:Any?] = ["account":account, "jid":jid, "received_id": receivedId, "read_id":readId]
        dispatcher.async {
            _ = try! self.insertLastMessage.insert(params)
        }
    }
    
    func updateMessage(account: BareJID, jid: BareJID, receivedId: String?, readId: String?) {
        let params: [String:Any?] = ["account":account, "jid":jid, "received_id": receivedId, "read_id":readId]
        dispatcher.async {
            _ = try! self.updateLastMessage.update(params)
        }
    }
    
    func getLastMessage(account: BareJID, jid: BareJID) -> LastMessageSync? {
        let params: [String:Any?] = ["account":account, "jid":jid]
        let message = try! self.getLastMessage.queryFirstMatching(params) { (cursor) -> LastMessageSync? in
            return LastMessageSync(account: account, jid: jid, receivedId: cursor["received_id"], readId: cursor["read_id"])
        }
        return message
    }
    
    func updateOrInsertLastMessage(account: BareJID, jid: BareJID, receivedId: String?, readId: String?) {
        dispatcher.async {
            let lastMessage = self.getLastMessage(account: account, jid: jid)
            if lastMessage != nil, receivedId != nil {
                self.updateMessage(account: account, jid: jid, receivedId: receivedId, readId: readId)
            }
            else if lastMessage == nil {
                self.insertmessage(account: account, jid: jid, receivedId: receivedId, readId: readId)
            }
        }
    }
}

struct LastMessageSync {
    var account : BareJID
    var jid : BareJID
    var receivedId : String?
    var readId : String?
}
