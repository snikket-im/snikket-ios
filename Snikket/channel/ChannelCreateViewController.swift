//
// ChannelCreateViewController.swift
//
// Siskin IM
// Copyright (C) 2020 "Tigase, Inc." <office@tigase.com>
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

class ChannelCreateViewController: UITableViewController, ChannelSelectAccountAndComponentControllerDelgate {
 
    @IBOutlet var joinButton: UIBarButtonItem!;
    @IBOutlet var statusView: ChannelJoinStatusView!;
    @IBOutlet var channelNameField: UITextField!;
    @IBOutlet var channelIdField: UITextField!;
    @IBOutlet weak var accountSelectorField: UITextField!
    
    lazy var accountPicker : UIPickerView = {
        let picker = UIPickerView()
        picker.dataSource = self
        picker.delegate = self
        return picker
    }()
    
    var account: BareJID? {
        didSet {
            statusView.account = account;
            needRefresh = true;
        }
    }
    var domain: String? {
        didSet {
            statusView.server = domain;
            needRefresh = true;
        }
    }
    
    var kind: ChannelKind = .adhoc;
    
    private var components: [ChannelsHelper.Component] = [] {
        didSet {
            updateJoinButtonStatus();
        }
    }
    private var invitationOnly: Bool = true;
    private var useMix: Bool = false;
    private var needRefresh = false;
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
        if account == nil {
            self.account = AccountManager.getActiveAccounts().first;
        }
        if needRefresh {
            self.refresh();
            needRefresh = false;
        }
        
        accountSelectorField.inputView = accountPicker
        accountSelectorField.text = self.account?.stringValue ?? ""
        accountSelectorField.delegate = self
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        
        if cell.reuseIdentifier == "SelectAccountCell" {
        }
        else if cell.reuseIdentifier == "ChannelNameCell" {
        }
        else if cell.reuseIdentifier == "AccessSwitchCell" {
            let view = UISwitch()
            view.isOn = self.invitationOnly
            view.addTarget(self, action: #selector(invitationOnlySwitchChanged(_:)), for: .valueChanged)
            cell.accessoryView = view
        }
        else if cell.reuseIdentifier == "ChannelIDCell" {
            
        }
        else if cell.reuseIdentifier == "ExperimentalCell" {
            let view = UISwitch();
            view.isOn = self.useMix;
            view.addTarget(self, action: #selector(mixSwitchChanged(_:)), for: .valueChanged);
            cell.accessoryView = view;
        }
        
        return cell
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        var count = super.numberOfSections(in: tableView)
        if kind == .adhoc { count -= 2 }
        if components.map({ $0.type }).contains(.mix) {
            return count;
        }
        return count - 1
    }
    
    @objc func invitationOnlySwitchChanged(_ sender: UISwitch) {
        invitationOnly = sender.isOn;
    }
    
    @objc func mixSwitchChanged(_ sender: UISwitch) {
        useMix = sender.isOn;
        updateJoinButtonStatus();
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destination = segue.destination as? ChannelSelectAccountAndComponentController {
            destination.delegate = self;
        }
        if let destination = segue.destination as? ChannelJoinViewController {
            destination.action = .create(isPublic: kind == .stable, invitationOnly: invitationOnly, description: nil, avatar: nil);
            destination.account = self.account;
            let component = self.components.first(where: { $0.type == (useMix ? .mix : .muc) })!;
            destination.channelJid = BareJID(domain: component.jid.domain);
            if kind == .stable {
                if let val = self.channelIdField.text, !val.isEmpty {
                    destination.channelJid = BareJID(localPart: val, domain: component.jid.domain);
                }
            }
            destination.name = channelNameField.text!;
            destination.componentType = useMix ? .mix : .muc;
        }
    }
    
    func operationStarted(message: String) {
        self.tableView.refreshControl = UIRefreshControl();
        self.tableView.refreshControl?.attributedTitle = NSAttributedString(string: message);
        self.tableView.refreshControl?.isHidden = false;
        self.tableView.refreshControl?.layoutIfNeeded();
        self.tableView.setContentOffset(CGPoint(x: 0, y: tableView.contentOffset.y - self.tableView.refreshControl!.frame.height), animated: true)
        self.tableView.refreshControl?.beginRefreshing();
    }
    
    func operationEnded() {
        self.tableView.refreshControl?.endRefreshing();
        self.tableView.refreshControl = nil;
    }

    @IBAction func cancelClicked(_ sender: Any) {
        self.dismiss(animated: true, completion: nil);
    }

    @IBAction func textFieldChanged(_ sender: Any) {
        updateJoinButtonStatus();
    }
    
    private func updateJoinButtonStatus() {
        if kind != .adhoc { self.joinButton.title = "Next" }
        let channelId = self.channelIdField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "";
        self.joinButton.isEnabled = (kind == .adhoc || !channelId.isEmpty) && self.components.contains(where: { $0.type == (useMix ? .mix : .muc) })
    }

    private func refresh() {
        guard let account = self.account else {
            return;
        }
        let domain = self.domain ?? account.domain;
        self.operationStarted(message: "Checking...");
        ChannelsHelper.findComponents(for: account, at: domain, completionHandler: { components in
            DispatchQueue.main.async {
                self.components = components;
                let types = Set(components.map({ $0.type }));
                if types.count == 1 {
                    switch types.first! {
                    case .mix:
                        self.useMix = true;
                    case .muc:
                        self.useMix = false;
                    }
                }
                self.tableView.reloadData();
                self.updateJoinButtonStatus();
                self.operationEnded();
            }
        })
    }
    
    enum ChannelKind {
        case stable
        case adhoc
    }
    
    @IBAction func createChannel(_ sender: UIBarButtonItem) {
        if kind == .adhoc {
            let component = self.components.first(where: { $0.type == (useMix ? .mix : .muc) })!
            let channelJid = BareJID(domain: component.jid.domain)
            let account = accountSelectorField.text ?? ""
            let nick = AccountSettings.displayName(BareJID(account)).getString() ?? BareJID(account).localPart
            self.create(account: BareJID(account), channelJid: channelJid, componentType: useMix ? .mix : .muc, name: channelNameField.text ?? "", description: nil, nick: nick ?? "", isPublic: false, invitationOnly: true, avatar: nil)
        }
        else {
            if let destination = UIStoryboard(name: "MIX", bundle: nil).instantiateViewController(withIdentifier: "ChannelJoinViewController") as? ChannelJoinViewController {
                destination.action = .create(isPublic: kind == .stable, invitationOnly: invitationOnly, description: nil, avatar: nil);
                destination.account = self.account;
                let component = self.components.first(where: { $0.type == (useMix ? .mix : .muc) })!;
                destination.channelJid = BareJID(domain: component.jid.domain);
                if kind == .stable {
                    if let val = self.channelIdField.text, !val.isEmpty {
                        destination.channelJid = BareJID(localPart: val, domain: component.jid.domain);
                    }
                }
                destination.name = channelNameField.text!;
                destination.componentType = useMix ? .mix : .muc
                destination.modalPresentationStyle = .formSheet
                self.navigationController?.pushViewController(destination, animated: true)
            }
        }
    }
    
    private func create(account: BareJID, channelJid: BareJID, componentType: ChannelsHelper.ComponentType, name: String, description: String?, nick: String, isPublic: Bool, invitationOnly: Bool, avatar: UIImage?) {
        switch componentType {
        case .mix:
            guard let client = XmppService.instance.getClient(for: account) else {
                return;
            }
            
            guard let mixModule: MixModule = client.modulesManager.getModule(MixModule.ID), let avatarModule: PEPUserAvatarModule = client.modulesManager.getModule(PEPUserAvatarModule.ID) else {
                return;
            }
            self.operationStarted(message: "Creating channel...")
                
            mixModule.create(channel: channelJid.localPart, at: BareJID(domain: channelJid.domain), completionHandler: { [weak self] result in
                switch result {
                case .success(let channelJid):
                        mixModule.join(channel: channelJid, withNick: nick, completionHandler: { result in
                            DispatchQueue.main.async {
                                self?.operationEnded();
                            }
                            switch result {
                            case .success(_):
                                DispatchQueue.main.async {
                                    self?.dismiss(animated: true, completion: nil);
                                }
                            case .failure(let errorCondition, _):
                                DispatchQueue.main.async {
                                    guard let that = self else {
                                        return;
                                    }
                                    let alert = UIAlertController(title: "Error occurred", message: "Could not join newly created channel '\(channelJid)' on the server. Got following error: \(errorCondition.rawValue)", preferredStyle: .alert);
                                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil));
                                    that.present(alert, animated: true, completion: nil);
                                }
                            }
                        })
                        mixModule.publishInfo(for: channelJid, info: ChannelInfo(name: name, description: description, contact: []), completionHandler: nil);
                        if let avatarData = avatar?.scaled(maxWidthOrHeight: 512.0)?.jpegData(compressionQuality: 0.8) {
                            avatarModule.publishAvatar(at: channelJid, data: avatarData, mimeType: "image/jpeg", completionHandler: { result in
                                print("avatar publication result:", result);
                            });
                        }
                        if invitationOnly {
                            mixModule.changeAccessPolicy(of: channelJid, isPrivate: invitationOnly, completionHandler: { result in
                                print("changed channel access policy:", result);
                            })
                        }
                    case .failure(let errorCondition):
                        DispatchQueue.main.async {
                            self?.operationEnded();
                            guard let that = self else {
                                return;
                            }
                            let alert = UIAlertController(title: "Error occurred", message: "Could not create channel on the server. Got following error: \(errorCondition.rawValue)", preferredStyle: .alert);
                            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil));
                            that.present(alert, animated: true, completion: nil);
                        }
                    }
                })
                break;
        case .muc:
            guard let client = XmppService.instance.getClient(for: account), let mucModule: MucModule = client.modulesManager.getModule(MucModule.ID) else {
                return;
            }
            let roomName = isPublic ? channelJid.localPart! : UUID().uuidString;
            _ = mucModule.join(roomName: roomName, mucServer: channelJid.domain, nickname: nick, ifCreated: { room in
                mucModule.getRoomConfiguration(roomJid: room.jid, onSuccess: { (config) in
                    if let roomNameField: TextSingleField = config.getField(named: "muc#roomconfig_roomname") {
                        roomNameField.value = name;
                    }
                    if let membersOnlyField: BooleanField = config.getField(named: "muc#roomconfig_membersonly") {
                        membersOnlyField.value = invitationOnly;
                        if invitationOnly {
                            if let anonimityField: ListSingleField = config.getField(named: "muc#roomconfig_anonymity") {
                                anonimityField.value = "nonanonymous";
                            }
                        }
                    }
                    if let whoisField: ListSingleField = config.getField(named: "muc#roomconfig_whois") {
                        if invitationOnly && whoisField.options.contains(where: { $0.value == "anyone" }) {
                            whoisField.value = "anyone";
                        }
                        if !invitationOnly && whoisField.options.contains(where: { $0.value == "moderators" }) {
                            whoisField.value = "moderators";
                        }
                    }
                    if let persistantField: BooleanField = config.getField(named: "muc#roomconfig_persistentroom") {
                        persistantField.value = true;
                    }
                    if let publicallySeachableField: BooleanField = config.getField(named: "muc#roomconfig_publicroom") {
                        publicallySeachableField.value = isPublic;
                    }
                    mucModule.setRoomConfiguration(roomJid: room.jid, configuration: config, onSuccess: {
                        PEPBookmarksModule.updateOrAdd(for: account, bookmark: Bookmarks.Conference(name: roomName, jid: room.jid, autojoin: true, nick: nick, password: nil));
                    }, onError: nil);
                }, onError: nil);
            }, onJoined: { room in
                DispatchQueue.main.async { [weak self] in
                    weak var pvc = self?.presentingViewController
                    (room as! DBRoom).supportedFeatures = []
                    self?.dismiss(animated: true, completion: {
                        if let vc = UIStoryboard(name: "Groupchat", bundle: nil).instantiateViewController(withIdentifier: "InviteViewController") as? InviteViewController {
                            vc.room = room
                            vc.modalPresentationStyle = .formSheet
                            vc.title = "Add Participants"
                            pvc?.present(UINavigationController(rootViewController: vc), animated: true, completion: nil)
                        }
                    })
                }
                if let vCardTempModule: VCardTempModule = client.modulesManager.getModule(VCardTempModule.ID) {
                    let vcard = VCard();
                    if let binval = avatar?.scaled(maxWidthOrHeight: 512.0)?.jpegData(compressionQuality: 0.8)?.base64EncodedString(options: []) {
                        vcard.photos = [VCard.Photo(uri: nil, type: "image/jpeg", binval: binval, types: [.home])];
                    }
                    vCardTempModule.publishVCard(vcard, to: room.roomJid);
                }
                if description != nil {
                    mucModule.setRoomSubject(roomJid: room.roomJid, newSubject: description);
                }
                room.registerForTigasePushNotification(true, completionHandler: { (result) in
                    print("automatically enabled push for:", room.roomJid, "result:", result);
                })
            })
        }
    }
    
}

extension ChannelCreateViewController: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return AccountManager.getActiveAccounts().count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return AccountManager.getActiveAccounts()[row].stringValue;
    }
    
    func  pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        accountSelectorField.text = self.pickerView(pickerView, titleForRow: row, forComponent: component)
        self.account = BareJID(accountSelectorField.text)
        self.refresh()
        self.view.endEditing(true)
    }
}

extension ChannelCreateViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        return false
    }
}
