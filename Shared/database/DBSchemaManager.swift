//
// DBSchemaManager.swift
//
// Siskin IM
// Copyright (C) 2017 "Tigase, Inc." <office@tigase.com>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. Look for COPYING file in the top folder.
// If not, see https://www.gnu.org/licenses/.
//

import Foundation
import TigaseSwift

public class DBSchemaManager {
    
    static let CURRENT_VERSION = 16;
    
    fileprivate let dbConnection: DBConnection;
    
    public init(dbConnection: DBConnection) {
        self.dbConnection = dbConnection;
    }
    
    open func upgradeSchema() throws {
        var version = try! getSchemaVersion();
        while (version < DBSchemaManager.CURRENT_VERSION) {
            switch version {
            case 0:
                try loadSchemaFile(fileName: "/db-schema-1.sql");
                do {
                    try dbConnection.execute("select preview from chat_history");
                } catch {
                    try dbConnection.execute("ALTER TABLE chat_history ADD COLUMN preview TEXT");
                }
                try cleanUpDuplicatedChats();
            case 1:
                try loadSchemaFile(fileName: "/db-schema-2.sql");
                try cleanUpDuplicatedChats();
            default:
                try loadSchemaFile(fileName: "/db-schema-\(version + 1).sql");
                break;
            }
            version = try! getSchemaVersion();
        }

        let journalMode = try dbConnection.prepareStatement("pragma journal_mode").findFirst(map: { cursor -> String? in
            return cursor["journal_mode"];
        })!;
        if journalMode != "wal" {
            try dbConnection.execute("PRAGMA journal_mode=WAL");
        }
        
        // need to make sure that "error" column exists as there was an issue with db-schema-2.sql
        // which did not create this column
        do {
            try dbConnection.execute("select error from chat_history");
        } catch {
            try dbConnection.execute("ALTER TABLE chat_history ADD COLUMN error TEXT;");
        }
        
        let toRemove: [(String,String,Int32)] = try dbConnection.prepareStatement("SELECT sess.account as account, sess.name as name, sess.device_id as deviceId FROM omemo_sessions sess WHERE NOT EXISTS (select 1 FROM omemo_identities i WHERE i.account = sess.account and i.name = sess.name and i.device_id = sess.device_id)").query([:] as [String: Any?], map: { (cursor:DBCursor) -> (String, String, Int32)? in
            return (cursor["account"]!, cursor["name"]!, cursor["deviceId"]!);
        });
        
        try toRemove.forEach { tuple in
            let (account, name, device) = tuple;
            _ = try dbConnection.prepareStatement("DELETE FROM omemo_sessions WHERE account = :account AND name = :name AND device_id = :deviceId").update(["account": account, "name": name, "deviceId": device] as [String: Any?]);
        }
    }
    
    open func getSchemaVersion() throws -> Int {
        return try self.dbConnection.prepareStatement("PRAGMA user_version").scalar() ?? 0;
    }
    
    fileprivate func loadSchemaFile(fileName: String) throws {
        guard let bundle = Bundle.allFrameworks.first(where: { (bundle) -> Bool in
            guard let resourcePath = bundle.resourcePath else {
                return false;
            }
            return FileManager.default.fileExists(atPath: resourcePath.appending(fileName));
        }) else {
            return;
        }
        let resourcePath = bundle.resourcePath! + fileName;
        print("loading SQL from file", resourcePath);
        let dbSchema = try String(contentsOfFile: resourcePath, encoding: String.Encoding.utf8);
        print("read schema:", dbSchema);
        try dbConnection.execute(dbSchema);
        print("loaded schema from file", fileName);
    }
    
    fileprivate func cleanUpDuplicatedChats() throws {
        // deal with duplicated chats for the same bare jid
        print("looking for duplicated chats...");
        let duplicates: [(String, String, Int)] = try dbConnection.prepareStatement("select min(c.id) as id, c.account, c.jid from (select count(id) as count, account, jid from chats group by account, jid) x inner join chats c on c.account = x.account and c.jid = x.jid where count > 1 group by c.account, c.jid").query() { (cursor) -> (String, String, Int) in
            let account: String = cursor["account"]!;
            let jid: String = cursor["jid"]!;
            let id: Int = cursor["id"] ?? 0;
            print("account", account, "jid", jid, "id", id);
            return (account, jid, id);
        }
        print("found duplicates", duplicates);
        try duplicates.forEach({ (account, jid, idToLeave) in
            let removed = try dbConnection.prepareStatement("delete from chats where account = ? and jid = ? and id <> :id").scalar(account, jid, idToLeave)!;
            print("for account", account, "and jid", jid, "removed", removed, "duplicated chats");
        });
        print("duplicated chats cleanup finished!");

    }
}
