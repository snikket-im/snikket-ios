//
// AccountSettingsViewController.swift
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

class AccountSettingsViewController: UITableViewController {
    
    var account: BareJID!;
    
    @IBOutlet var avatarView: UIImageView!
    @IBOutlet var fullNameTextView: UILabel!
    @IBOutlet var companyTextView: UILabel!
    @IBOutlet var addressTextView: UILabel!
    
    @IBOutlet var enabledSwitch: UISwitch!
    @IBOutlet var nicknameLabel: UILabel!;
    @IBOutlet var pushNotificationsForAwaySwitch: UISwitch!
    
    @IBOutlet weak var telephonyProviderLabel: UILabel!
    
    @IBOutlet var omemoFingerprint: UILabel!;
    
    override func viewDidLoad() {
        tableView.contentInset = UIEdgeInsets(top: -1, left: 0, bottom: 0, right: 0);
        NotificationCenter.default.addObserver(self, selector: #selector(refreshOnNotification), name: XmppService.ACCOUNT_STATE_CHANGED, object: nil);
        NotificationCenter.default.addObserver(self, selector: #selector(refreshOnNotification), name: DiscoEventHandler.ACCOUNT_FEATURES_RECEIVED, object: nil);
        NotificationCenter.default.addObserver(self, selector: #selector(refreshOnNotification), name: DiscoEventHandler.SERVER_FEATURES_RECEIVED, object: nil);
        NotificationCenter.default.addObserver(self, selector: #selector(avatarChanged), name: AvatarManager.AVATAR_CHANGED, object: nil);
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
        navigationItem.title = account.stringValue;

        
        let config = AccountManager.getAccount(for: account);
        enabledSwitch.isOn = config?.active ?? false;
        nicknameLabel.text = config?.nickname;
        pushNotificationsForAwaySwitch.isOn = AccountSettings.PushNotificationsForAway(account).getBool();

        updateView();
        
        let vcard = XmppService.instance.dbVCardsCache.getVCard(for: account);
        update(vcard: vcard);

        //avatarView.sizeToFit();
        avatarView.layer.masksToBounds = true;
        avatarView.layer.cornerRadius = avatarView.frame.width / 2;
        
        let localDeviceId = Int32(bitPattern: AccountSettings.omemoRegistrationId(self.account).getUInt32() ?? 0);
        if let omemoIdentity = DBOMEMOStore.instance.identities(forAccount: self.account, andName: self.account.stringValue).first(where: { (identity) -> Bool in
            return identity.address.deviceId == localDeviceId;
        }) {
            var fingerprint = String(omemoIdentity.fingerprint.dropFirst(2));
            var idx = fingerprint.startIndex;
            for _ in 0..<(fingerprint.count / 8) {
                idx = fingerprint.index(idx, offsetBy: 8);
                fingerprint.insert(" ", at: idx);
                idx = fingerprint.index(after: idx);
            }
            omemoFingerprint.text = fingerprint;
        } else {
            omemoFingerprint.text = NSLocalizedString("Key not generated!",comment: "")
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        //avatarView.sizeToFit();
        avatarView.layer.masksToBounds = true;
        avatarView.layer.cornerRadius = avatarView.frame.width / 2;
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated);
    }

    
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if indexPath.row == 0 && indexPath.section == 1 {
            return nil;
        }
        if indexPath.section == 1 && indexPath.row == 1 && XmppService.instance.getClient(for: account)?.state != .connected {
            return nil;
        }
        return indexPath;
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false);
        if indexPath.section == 1 && indexPath.row == 3 {
            let controller = UIAlertController(title: NSLocalizedString("Nickname",comment: ""), message: NSLocalizedString("Enter default nickname to use in chats",comment: ""), preferredStyle: .alert);
            controller.addTextField(configurationHandler: { textField in
                textField.text = AccountManager.getAccount(for: self.account)?.nickname ?? "";
            });
            controller.addAction(UIAlertAction(title: NSLocalizedString("OK",comment: ""), style: .default, handler: { _ in
                let nickname = controller.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines);
                if let account = AccountManager.getAccount(for: self.account) {
                    account.nickname = nickname;
                    AccountManager.save(account: account);
                    self.nicknameLabel.text = account.nickname;
                }
            }))
            self.navigationController?.present(controller, animated: true, completion: nil);
        }
        
        if indexPath.section == 5 && indexPath.row == 0 {
            self.logOutSheet(indexPath: indexPath)
        } else if indexPath.section == 5 && indexPath.row == 1 {
            self.deleteAccountSheet(indexPath: indexPath)
        }
        
        if indexPath.section == 2 && indexPath.row == 0 {
            let client = XmppService.instance.getClient(for: account)
            let pushModule: SiskinPushNotificationsModule? = client?.modulesManager.getModule(SiskinPushNotificationsModule.ID)
            if (PushEventHandler.instance.deviceId != nil) && (pushModule?.isAvailable ?? false) {
                self.reRegisterPushNotifications()
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return nil;
        }
        return super.tableView(tableView, titleForHeaderInSection: section);
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 {
            return 1.0;
        }
        return super.tableView(tableView, heightForHeaderInSection: section);
    }
    
    func updateView() {
        let client = XmppService.instance.getClient(for: account);
        let pushModule: SiskinPushNotificationsModule? = client?.modulesManager.getModule(SiskinPushNotificationsModule.ID);
        pushNotificationsForAwaySwitch.isEnabled = (pushModule?.isSupported(extension: TigasePushNotificationsModule.PushForAway.self) ?? false);
        telephonyProviderLabel.text = AccountSettings.telephonyProvider(account).getString() ?? "None"
    }
    
    @objc func avatarChanged() {
        let vcard = XmppService.instance.dbVCardsCache.getVCard(for: account);
        DispatchQueue.main.async {
            self.update(vcard: vcard);
        }
    }
    
    @objc func refreshOnNotification() {
        DispatchQueue.main.async {
            self.updateView();
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard segue.identifier != nil else {
            return;
        }
        switch segue.identifier! {
        case "AccountQRCodeController":
            let destination = segue.destination as! AccountQRCodeController;
            destination.account = account;
        case "EditAccountSegue":
            let destination = segue.destination as! AddAccountController;
            destination.account = account.stringValue;
        case "EditAccountVCardSegue":
            let destination = segue.destination as! VCardEditViewController;
            destination.account = account;
        case "ShowServerFeatures":
            let destination = segue.destination as! ServerFeaturesViewController;
            destination.account = account;
        case "ManageOMEMOFingerprints":
            let destination = segue.destination as! OMEMOFingerprintsController;
            destination.account = account;
        case "ShowTelephonyProviders":
            let destination = segue.destination as! TelephonyProviderViewController
            destination.account = account
        default:
            break;
        }
    }
        
    @IBAction func enabledSwitchChangedValue(_ sender: AnyObject) {
        if let config = AccountManager.getAccount(for: account!) {
            config.active = enabledSwitch.isOn;
            AccountSettings.LastError(account).set(string: nil);
            AccountManager.save(account: config);
        }
    }
    
    func reRegisterPushNotifications() {
        let alert = UIAlertController(title: NSLocalizedString("Push Notifications",comment: ""), message: NSLocalizedString("Snikket can be automatically notified by compatible XMPP servers about new messages when it is in background or stopped.\nIf enabled, notifications about new messages will be forwarded to our push component and delivered to the device. These notifications may contain message senders jid and part of a message.\nDo you want to enable push notifications?",comment: ""), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("Yes",comment: ""), style: .default, handler: self.enablePushNotifications))
        alert.addAction(UIAlertAction(title: NSLocalizedString("No",comment: ""), style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    fileprivate func enablePushNotifications(action: UIAlertAction) {
        let accountJid = self.account!;
        let onError = { (_ errorCondition: ErrorCondition?) in
            DispatchQueue.main.async {
                var userInfo: [AnyHashable:Any] = ["account": accountJid];
                if errorCondition != nil {
                    userInfo["errorCondition"] = errorCondition;
                }
                NotificationCenter.default.post(name: Notification.Name("pushNotificationsRegistrationFailed"), object: self, userInfo: userInfo);
            }
        }
        // let's check if push notifications component is accessible
        if let pushModule: SiskinPushNotificationsModule = XmppService.instance.getClient(forJid: accountJid)?.modulesManager.getModule(SiskinPushNotificationsModule.ID), let deviceId = PushEventHandler.instance.deviceId {
            pushModule.registerDeviceAndEnable(deviceId: deviceId, pushkitDeviceId: PushEventHandler.instance.pushkitDeviceId, completionHandler: { result in
                switch result {
                case .success(_):
                    break;
                case .failure(let errorCondition):
                    DispatchQueue.main.async {
                        self.pushNotificationsForAwaySwitch.isOn = false;
                    }
                    onError(errorCondition);
                }
            });
        } else {
            pushNotificationsForAwaySwitch.isOn = false;
            onError(ErrorCondition.service_unavailable);
        }
    }
    
    @IBAction func pushNotificationsForAwaySwitchChangedValue(_ sender: Any) {
        
        AccountSettings.PushNotificationsForAway(account).set(bool: self.pushNotificationsForAwaySwitch.isOn);
        guard let pushModule: SiskinPushNotificationsModule = XmppService.instance.getClient(for: account)?.modulesManager.getModule(SiskinPushNotificationsModule.ID) else {
            return;
        }
        
        guard let pushSettings = pushModule.pushSettings else {
            return;
        }
        pushModule.reenable(pushSettings: pushSettings, completionHandler: { (result) in
            switch result {
            case .success(_):
                print("PUSH enabled!");
                DispatchQueue.main.async {
                    guard self.pushNotificationsForAwaySwitch.isOn else {
                        return;
                    }
                    let syncPeriod = AccountSettings.messageSyncPeriod(self.account).getDouble();
                    if !AccountSettings.messageSyncAuto(self.account).getBool() || syncPeriod < 12 {
                        let alert = UIAlertController(title: NSLocalizedString("Enable automatic message synchronization",comment: ""), message: NSLocalizedString("For best experience it is suggested to enable Message Archving with automatic message synchronization of at least last 12 hours.\nDo you wish to do this now?",comment: ""), preferredStyle: .alert);
                        alert.addAction(UIAlertAction(title: NSLocalizedString("No",comment: ""), style: .cancel, handler: nil));
                        alert.addAction(UIAlertAction(title: NSLocalizedString("Yes",comment: ""), style: .default, handler: {(action) in
                            AccountSettings.messageSyncAuto(self.account).set(bool: true);
                            if (syncPeriod < 12) {
                                AccountSettings.messageSyncPeriod(self.account).set(double: 12.0);
                            }
                            self.updateView();
                        }));
                        self.present(alert, animated: true, completion: nil);
                    }
                }
            case .failure(_):
                DispatchQueue.main.async {
                    self.pushNotificationsForAwaySwitch.isOn = !self.pushNotificationsForAwaySwitch.isOn;
                    AccountSettings.PushNotificationsForAway(self.account).set(bool: self.pushNotificationsForAwaySwitch.isOn);
                }
            }
        });
    }
    
    func setPushNotificationsEnabled(forJid account: BareJID, value: Bool) {
        if let config = AccountManager.getAccount(for: account) {
            config.pushNotifications = value
            AccountManager.save(account: config);
        }
    }
    
    func update(vcard: VCard?) {
        avatarView.image = AvatarManager.instance.avatar(for: account, on: account) ?? AvatarManager.instance.defaultAvatar;
        
        if let fn = vcard?.fn {
            fullNameTextView.text = fn;
        } else if let surname = vcard?.surname, let given = vcard?.givenName {
            fullNameTextView.text = "\(given) \(surname)";
        } else {
            fullNameTextView.text = account.stringValue;
        }
        
        let company = vcard?.organizations.first?.name;
        let role = vcard?.role;
        if role != nil && company != nil {
            companyTextView.text = "\(role!) at \(company!)";
            companyTextView.isHidden = false;
        } else if company != nil {
            companyTextView.text = company;
            companyTextView.isHidden = false;
        } else if role != nil {
            companyTextView.text = role;
            companyTextView.isHidden = false;
        } else {
            companyTextView.isHidden = true;
        }
        
        let addresses = vcard?.addresses.filter { (addr) -> Bool in
            return !addr.isEmpty;
        };
        
        if let address = addresses?.first {
            var tmp = [String]();
            if address.street != nil {
                tmp.append(address.street!);
            }
            if address.locality != nil {
                tmp.append(address.locality!);
            }
            if address.country != nil {
                tmp.append(address.country!);
            }
            addressTextView.text = tmp.joined(separator: ", ");
        } else {
            addressTextView.text = nil;
        }
    }
    
    func disableAccount() {
        if let config = AccountManager.getAccount(for: account) {
            config.active = false
            AccountSettings.LastError(account).set(string: nil);
            AccountManager.save(account: config);
        }
        
        if let client = XmppService.instance.getClient(forJid: account) {
            client.disconnect()
        }
        self.navigationController?.popViewController(animated: true)
    }
    
    func logOutSheet(indexPath: IndexPath) {
        let sheet = UIAlertController(title: NSLocalizedString("Log Out", comment: ""), message: NSLocalizedString("You can log out of this account temporarily, or permanently remove all account data from this device (including chats). Account removal cannot be undone.", comment: ""), preferredStyle: .actionSheet)
        
        let removeDataAction = UIAlertAction(title: NSLocalizedString("Remove Account Data", comment: ""), style: .destructive) { _ in
            self.deleteAccountData(fromServer: false)
        }
        
        let logOutAction = UIAlertAction(title: NSLocalizedString("Log Out", comment: ""), style: .default) { _ in
            self.disableAccount()
        }
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil)
        
        sheet.addAction(removeDataAction)
        sheet.addAction(logOutAction)
        sheet.addAction(cancelAction)
        
        sheet.popoverPresentationController?.sourceView = self.tableView
        sheet.popoverPresentationController?.sourceRect = self.tableView.rectForRow(at: indexPath)
        self.present(sheet, animated: true, completion: nil)
    }
    
    func deleteAccountSheet(indexPath: IndexPath) {
        
        let sheet = UIAlertController(title: NSLocalizedString("Permanently Delete Account", comment: ""), message: String.localizedStringWithFormat(NSLocalizedString("Deleting your account will permanently log out all your devices and delete your account, profile, and associated data on %@.", comment: ""), account.domain), preferredStyle: .actionSheet)
        
        let deleteAction = UIAlertAction(title: NSLocalizedString("Delete My Account", comment: ""), style: .destructive) { _ in
            self.deleteAccountData(fromServer: true)
        }
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil)
        
        sheet.addAction(deleteAction)
        sheet.addAction(cancelAction)
        sheet.popoverPresentationController?.sourceView = self.tableView
        sheet.popoverPresentationController?.sourceRect = self.tableView.rectForRow(at: indexPath)
        self.present(sheet, animated: true, completion: nil)
    }
    
    func deleteAccountData(fromServer: Bool) {
        
        guard let account = self.account, let config = AccountManager.getAccount(for: account) else { return }
        
        if let pushSettings = config.pushSettings {
            if let client = XmppService.instance.getClient(forJid: BareJID(account)), client.state == .connected, let pushModule: SiskinPushNotificationsModule = client.modulesManager.getModule(SiskinPushNotificationsModule.ID) {
                
                pushModule.unregisterDeviceAndDisable(completionHandler: { result in
                    switch result {
                    case .success(_):
                        // now remove the account...
                        self.removeAccount(account: account, fromServer: fromServer)
                        break
                    case .failure(_):
                        PushEventHandler.unregisterDevice(from: pushSettings.jid.bareJid, account: account, deviceId: pushSettings.deviceId, completionHandler: { result in
                            config.pushSettings = nil
                            AccountManager.save(account: config)
                            DispatchQueue.main.async {
                                switch result {
                                case .success(_):
                                    self.removeAccount(account: account, fromServer: fromServer)
                                case .failure( _):
                                    let alert = UIAlertController(title: NSLocalizedString("Account Removal Failed",comment: "Alert title"), message: String.localizedStringWithFormat(NSLocalizedString("Push notifications are enabled for %@. They need to be disabled before account can be removed and it is not possible to at this time. Please try again later.", comment: ""), account.stringValue), preferredStyle: .alert);
                                    alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: nil));
                                    self.present(alert, animated: true, completion: nil);
                                }
                            }
                        })
                    }
                });
                
            }
            else {
                PushEventHandler.unregisterDevice(from: pushSettings.jid.bareJid, account: account, deviceId: pushSettings.deviceId, completionHandler: { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(_):
                            config.pushSettings = nil
                            AccountManager.save(account: config)
                            self.removeAccount(account: account, fromServer: fromServer)
                        case .failure( _):
                            let alert = UIAlertController(title: NSLocalizedString("Account Removal Failed", comment: "Alert title"), message: String.localizedStringWithFormat(NSLocalizedString("Push notifications are enabled for %@. They need to be disabled before account can be removed and it is not possible to at this time. Please try again later.", comment: ""), account.stringValue), preferredStyle: .alert);
                            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: nil));
                            self.present(alert, animated: true, completion: nil);
                        }
                    }
                })
            }
        }
        else {
            self.removeAccount(account: account, fromServer: fromServer)
        }
    }
    
    func removeAccount(account: BareJID, fromServer: Bool) {
        
        if fromServer {
            if let client = XmppService.instance.getClient(forJid: BareJID(account)), client.state == .connected {
                let regModule = client.modulesManager.register(InBandRegistrationModule())
                regModule.unregister({ (stanza) in
                    DispatchQueue.main.async() {
                        _ = AccountManager.deleteAccount(for: account)
                        self.navigationController?.popViewController(animated: true)
                    }
                })
            } else {
                DispatchQueue.main.async {
                    let alert = UIAlertController(title: NSLocalizedString("Account Removal Failed",comment: "Alert title"), message: NSLocalizedString("Could not connect to the service. Check your network connectivity or try again later.",comment: ""), preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: NSLocalizedString("OK",comment: ""), style: .default, handler: { _ in
                        self.tableView.reloadData()
                    }))
                    self.present(alert, animated: true, completion: nil)
                }
            }
        } else {
            DispatchQueue.main.async {
                _ = AccountManager.deleteAccount(for: account)
                self.navigationController?.popViewController(animated: true)
            }
        }
    }

    class SyncTimeItem: TablePickerViewItemsProtocol {
        
        public static func descriptionFromHours(hours: Double) -> String {
            if (hours == 0) {
                return NSLocalizedString("Nothing", comment: "How many messages to fetch from the server")
            } else if (hours >= 24*365) {
                return NSLocalizedString("All", comment: "How many messages to fetch from the server")
            } else if (hours > 24) {
                return String.localizedStringWithFormat(NSLocalizedString("Last %d days", comment: "Placeholder is number of days (sync period)"), Int(hours/24))
            } else {
                return String.localizedStringWithFormat(NSLocalizedString("Last %d hours", comment: "Placeholder is hours value (sync period)"), Int(hours))
            }
        }
        
        let description: String;
        let hours: Double;
        
        init(hours: Double) {
            self.hours = hours;
            self.description = SyncTimeItem.descriptionFromHours(hours: hours);
        }
        
    }
}
