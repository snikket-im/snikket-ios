//
// InviteViewController.swift
//
// Siskin IM
// Copyright (C) 2019 "Tigase, Inc." <office@tigase.com>
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
import TigaseSwift

class InviteViewController: AbstractRosterViewController {

    var room: Room!;
    
    var onNext: (([JID])->Void)? = nil;
    
    var selected: [JID] = [] {
        didSet {
            if selected.isEmpty {
                self.navigationItem.rightBarButtonItem = nil
            } else {
                self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Invite", style: .plain, target: self, action: #selector(inviteUsers))
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        allowsMultipleSelection = true
        self.tableView.allowsMultipleSelection = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
        
        if onNext != nil {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Create", style: .plain, target: self, action: #selector(selectionFinished(_:)))
        } else {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel(_:)));
        }
    }
    
    @objc func cancel(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil);
    }
    
    @objc func selectionFinished(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil);
        
        if let onNext = self.onNext {
            self.onNext = nil;
            print("calling onNext!");
            onNext(selected);
        }
    }
    
    @objc func inviteUsers() {
        for user in selected {
            room.invite(user, reason: "You are invied to join conversation at \(room.roomJid)")
        }
        self.navigationController?.dismiss(animated: true, completion: nil);
    }
        
    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        guard let item = roster?.item(at: indexPath) else { return }
        
        let cell = self.tableView.cellForRow(at: indexPath)
        cell?.accessoryType = .checkmark
        
        self.selected.append(item.jid)
    }
 
    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        guard let item = roster?.item(at: indexPath) else {
            return;
        }
        selected = selected.filter({ (jid) -> Bool in
            return jid != item.jid;
        });
    }
    
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        guard let item = roster?.item(at: indexPath) else { return nil }
        
        if let selectedRows = tableView.indexPathsForSelectedRows, selectedRows.contains(indexPath) { 
            let cell = self.tableView.cellForRow(at: indexPath)
            cell?.accessoryType = .none
            tableView.deselectRow(at: indexPath, animated: true)
            selected = selected.filter({ (jid) -> Bool in
                return jid != item.jid;
            })
            return nil
        }
        return indexPath
    }
}
