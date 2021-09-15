//
// MucChatOccupantsTableViewController.swift
//
// Siskin IM
// Copyright (C) 2016 "Tigase, Inc." <office@tigase.com>
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

class MucChatOccupantsTableViewController: UITableViewController {
    
    var xmppService:XmppService!;
    
    var account: BareJID!;
    var room: DBRoom! {
        didSet {
            self.members = room.roomOccupants ?? []
            tableView?.reloadData()
        }
    }
    
    private var members: [MucModule.RoomAffiliation] = []
    
    var mentionOccupant: ((String)->Void)? = nil;
    
    //private var participants: [MucOccupant] = [];
    
    override func viewDidLoad() {
        xmppService = (UIApplication.shared.delegate as! AppDelegate).xmppService;
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        
        NotificationCenter.default.addObserver(self, selector: #selector(occupantsChanged(_:)), name: MucEventHandler.ROOM_OCCUPANTS_CHANGED, object: nil);
        NotificationCenter.default.addObserver(self, selector: #selector(roomStatusChanged), name: MucEventHandler.ROOM_STATUS_CHANGED, object: nil);
        NotificationCenter.default.addObserver(self, selector: #selector(mucUpdated), name: DBChatStore.MUC_UPDATED, object: nil);
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
        self.members.sort(by: { (i1, i2) -> Bool in
            let nick1 = i1.nickname ?? PEPDisplayNameModule.getDisplayName(account: self.account, for: i1.jid.bareJid)
            let nick2 = i2.nickname ?? PEPDisplayNameModule.getDisplayName(account: self.account, for: i2.jid.bareJid)
            return nick1.caseInsensitiveCompare(nick2) == .orderedAscending
        })
        tableView.reloadData()
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated);
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in: UITableView) -> Int {
        return 1;
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return members.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MucChatOccupantsTableViewCell", for: indexPath as IndexPath) as! MucChatOccupantsTableViewCell;
        
        let occupant = members[indexPath.row]
        let nick = occupant.nickname ?? PEPDisplayNameModule.getDisplayName(account: self.account, for: occupant.jid.bareJid)
        cell.nicknameLabel.text = nick
        if let avatar = AvatarManager.instance.avatar(for: occupant.jid.bareJid, on: self.account) {
            cell.avatarStatusView.set(name: nick, avatar: avatar, orDefault: AvatarManager.instance.defaultAvatar);
        }  else {
            cell.avatarStatusView.set(name: nick, avatar: nil, orDefault: AvatarManager.instance.defaultAvatar);
        }
        cell.avatarStatusView.statusImageView.isHidden = true
        cell.statusLabel.text = occupant.role?.rawValue ?? "Member"
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return false;
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true);
        
        let occupant = members[indexPath.row];

        if let fn = mentionOccupant {
            fn(occupant.nickname ?? occupant.jid.stringValue);
        }
        self.navigationController?.popViewController(animated: true);
    }
    
    @available(iOS 13.0, *)
    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard room.state == .joined else {
            return nil;
        }
        
        let participant = self.members[indexPath.row];
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: { suggestedActions in
            var actions: [UIAction] = [];
            actions.append(UIAction(title: "Private message", handler: { action in
                let alert = UIAlertController(title: "Send message", message: "Enter message to send to: \(participant.nickname ?? participant.jid.stringValue)", preferredStyle: .alert);
                alert.addTextField(configurationHandler: nil);
                alert.addAction(UIAlertAction(title: "Send", style: .default, handler: { action in
                    guard let text = alert.textFields?.first?.text else {
                        return;
                    }
                    MucEventHandler.instance.sendPrivateMessage(room: self.room, recipientNickname: participant.nickname ?? participant.jid.stringValue, body: text);
                }));
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil));
                self.present(alert, animated: true, completion: nil);
            }));
            if self.room.presences[self.room.nickname]?.affiliation == MucAffiliation.admin {
                actions.append(UIAction(title: "Ban user", handler: { action in
                    guard let mucModule: MucModule = XmppService.instance.getClient(for: self.room.account)?.modulesManager.getModule(MucModule.ID) else {
                        return;
                    }
                    let alert = UIAlertController(title: "Banning user", message: "Do you want to ban user \(participant.nickname ?? participant.jid.stringValue)?", preferredStyle: .alert);
                    alert.addAction(UIAlertAction(title: "Yes", style: .destructive, handler: { action in
                        mucModule.setRoomAffiliations(to: self.room, changedAffiliations: [MucModule.RoomAffiliation(jid: participant.jid, affiliation: .outcast)], completionHandler: { error in
                            guard let err = error else {
                                return;
                            }
                            let alert = UIAlertController(title: "Banning user \(participant.nickname ?? participant.jid.stringValue) failed", message: "Server returned an error: \(err.rawValue)", preferredStyle: .alert);
                            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil));
                            self.present(alert, animated: true, completion: nil);
                        })
                    }))
                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil));
                    self.present(alert, animated: true, completion: nil);
                }));
            }
            return UIMenu(title: "", children: actions);
        });
    }

    /*
    // Override to support editing the table view.
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            // Delete the row from the data source
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        } else if editingStyle == .Insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let invitationController = segue.destination as? InviteViewController ?? (segue.destination as? UINavigationController)?.visibleViewController as? InviteViewController {
            invitationController.room = self.room;
        }
    }
    
    @objc func occupantsChanged(_ notification: Notification) {
        guard let event = notification.object as? MucModule.AbstractOccupantEvent else {
            guard let occupant = notification.object as? MucOccupant, let jid = occupant.jid else {
                return;
            }
            let member = MucModule.RoomAffiliation(jid: jid, affiliation: occupant.affiliation, nickname: occupant.nickname, role: occupant.role)
            DispatchQueue.main.async {
                var tmp = self.members
                tmp.append(member)
                tmp.sort(by: { (i1, i2) -> Bool in
                    return i1.nickname?.caseInsensitiveCompare(i2.nickname ?? "") == .orderedAscending;
                })
                guard let idx = tmp.firstIndex(where: { (i) -> Bool in
                    i.nickname == occupant.nickname;
                }) else {
                    return;
                }
                self.members = tmp
                self.tableView?.insertRows(at: [IndexPath(row: idx, section: 0)], with: .automatic);
            }
            return;
        }
        guard let room = self.room, event.room === room else {
            return;
        }
        
        switch event {
        case let e as MucModule.OccupantComesEvent:
            DispatchQueue.main.async {
                var tmp = self.members
                let member = MucModule.RoomAffiliation(jid: e.occupant.jid!, affiliation: e.occupant.affiliation, nickname: e.occupant.nickname, role: e.occupant.role)
                if let idx = tmp.firstIndex(where: { (i) -> Bool in
                    i.nickname == e.occupant.nickname;
                }) {
                    tmp[idx] = member
                    self.members = tmp
                    self.tableView?.reloadRows(at: [IndexPath(row: idx, section: 0)], with: .automatic);
                } else {
                    tmp.append(member)
                    tmp.sort(by: { (i1, i2) -> Bool in
                        return i1.nickname?.caseInsensitiveCompare(i2.nickname ?? "") == .orderedAscending;
                    })
                    guard let idx = tmp.firstIndex(where: { (i) -> Bool in
                        i.nickname == e.occupant.nickname;
                    }) else {
                        return;
                    }
                    self.members = tmp
                    self.tableView?.insertRows(at: [IndexPath(row: idx, section: 0)], with: .automatic);
                }
            }
        case let e as MucModule.OccupantLeavedEvent:
            DispatchQueue.main.async {
                var tmp = self.members
                guard let idx = tmp.firstIndex(where: { (i) -> Bool in
                    i.nickname == e.occupant.nickname;
                }) else {
                    return;
                }
                tmp.remove(at: idx);
                self.members = tmp
                self.tableView?.deleteRows(at: [IndexPath(row: idx, section: 0)], with: .automatic);
            }
        case let e as MucModule.OccupantChangedPresenceEvent:
            DispatchQueue.main.async {
                var tmp = self.members
                let member = MucModule.RoomAffiliation(jid: e.occupant.jid!, affiliation: e.occupant.affiliation, nickname: e.occupant.nickname, role: e.occupant.role)
                guard let idx = tmp.firstIndex(where: { (i) -> Bool in
                    i.nickname == e.occupant.nickname;
                }) else {
                    return;
                }
                tmp[idx] = member
                self.members = tmp
                self.tableView?.reloadRows(at: [IndexPath(row: idx, section: 0)], with: .automatic);
            }
        case let e as MucModule.OccupantChangedNickEvent:
            DispatchQueue.main.async {
                var tmp = self.members
                let member = MucModule.RoomAffiliation(jid: e.occupant.jid!, affiliation: e.occupant.affiliation, nickname: e.occupant.nickname, role: e.occupant.role)
                guard let oldIdx = tmp.firstIndex(where: { (i) -> Bool in
                    i.nickname == e.nickname;
                }) else {
                    return;
                }
                tmp.remove(at: oldIdx);
                tmp.append(member)
                tmp.sort(by: { (i1, i2) -> Bool in
                    return i1.nickname?.caseInsensitiveCompare(i2.nickname ?? "") == .orderedAscending;
                })
                guard let newIdx = tmp.firstIndex(where: { (i) -> Bool in
                    i.nickname == e.occupant.nickname;
                }) else {
                    return;
                }
                
                self.members = tmp
                self.tableView?.moveRow(at: IndexPath(row: oldIdx, section: 0), to: IndexPath(row: newIdx, section: 0));
                self.tableView?.reloadRows(at: [IndexPath(row: newIdx, section: 0)], with: .automatic);
            }
        default:
            break;
        }
    }
    
    @objc func roomStatusChanged(_ notification: Notification) {
        guard let room = notification.object as? DBRoom, (self.room?.id ?? 0) == room.id else {
            return;
        }
        
        if room.state != .joined {
            DispatchQueue.main.async {
                self.members.removeAll()
                self.tableView?.reloadData();
            }
        }
    }
    
    @objc func mucUpdated() {
        self.members = room.roomOccupants ?? []
        self.members.sort(by: { (i1, i2) -> Bool in
            let nick1 = i1.nickname ?? PEPDisplayNameModule.getDisplayName(account: self.account, for: i1.jid.bareJid)
            let nick2 = i2.nickname ?? PEPDisplayNameModule.getDisplayName(account: self.account, for: i2.jid.bareJid)
            return nick1.caseInsensitiveCompare(nick2) == .orderedAscending
        })
        tableView.reloadData()
    }

}
