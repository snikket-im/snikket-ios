//
// AccountsTableViewController.swift
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

import UIKit

class AccountsTableViewController: UITableViewController {
    
    var accounts: [String] = [];
    
    var delegate: ShareViewController?;
    
    var selected: String? = nil;
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        accounts = getAccounts()
        self.tableView.reloadData()
    }
    
    func getAccounts() -> [String] {
        var accounts = [String]();
        let query = [ String(kSecClass) : kSecClassGenericPassword,
                      String(kSecMatchLimit) : kSecMatchLimitAll,
                      String(kSecReturnAttributes) : kCFBooleanTrue!,
                      String(kSecAttrService) : "xmpp" as NSObject] as [String : Any]
        
        var result:CFTypeRef?;
        
        guard SecItemCopyMatching(query as CFDictionary, &result) == noErr else {
            return []
        }
        
        if let results = result as? [[String:NSObject]] {
            print(results)
            for r in results {
                let name = r[String(kSecAttrAccount)] as! String;
                if let data = r[String(kSecAttrGeneric)] as? NSData {
                    let dict = NSKeyedUnarchiver.unarchiveObject(with: data as Data) as? [String:AnyObject];
                    accounts.append(name)
//                    if dict!["active"] as? Bool ?? false {
//                        accounts.append(name)
//                    }
                }
            }
        }
        return accounts
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1;
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return accounts.count;
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "accountTableViewCell", for: indexPath) as! AccountTableViewCell;
        let name = accounts[indexPath.row];
        cell.accountLabel.text = name;
        if selected != nil && selected! == name {
            cell.accessoryType = .checkmark;
        } else {
            cell.accessoryType = .none;
        }
        return cell;
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let account = accounts[indexPath.row];
        selected = account;
        delegate!.accountSelection(account: account);
        navigationController?.popViewController(animated: true);
    }
}
