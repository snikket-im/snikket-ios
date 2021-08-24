//
// VCardEditViewController.swift
//
// Siskin IMM
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

class VCardEditViewController: UITableViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    var xmppService: XmppService!;
        
    var avatarImage: UIImage?
    var displayname = ""
    var account: BareJID!;
    var vcard: VCard!;
    var isUpdatingAvatar = false
    
    let picker = UIImagePickerController()
    
    override func viewDidLoad() {
        xmppService = (UIApplication.shared.delegate as! AppDelegate).xmppService;
        super.viewDidLoad()
        
        avatarImage = AvatarManager.instance.avatar(for: account, on: account)
        self.tableView.reloadData()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setDisplayName()
    }
    
    func setDisplayName() {
        
        if let account = account, let displayName = AccountSettings.displayName(account).getString() {
            self.displayname = displayName
        }
        self.tableView.reloadData()
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "AvatarEditCell") as! VCardAvatarEditCell;
            cell.avatarView.set(name: nil, avatar: nil, orDefault: AvatarManager.instance.defaultAvatar);
            cell.avatarView.set(name: nil, avatar: avatarImage, orDefault: AvatarManager.instance.defaultAvatar)
            if isUpdatingAvatar { cell.spinner.startAnimating() }
            else { cell.spinner.stopAnimating() }
            cell.updateCornerRadius();
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "TextEditCell") as! VCardTextEditCell;
            cell.textField.placeholder = "Name"
            cell.textField.text = self.displayname
            cell.textField.isUserInteractionEnabled = false
            cell.textField.tag = indexPath.row;
            
            cell.contentView.clipsToBounds = true
            cell.textField.layer.cornerRadius = 5
            cell.textField.layer.borderWidth = 1
            cell.textField.layer.borderColor = UIColor.darkGray.cgColor
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        (cell as? VCardAvatarEditCell)?.updateCornerRadius();
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return nil
        case 1:
            return "Display Name"
        default:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 {
            return 1.0
        }
        return super.tableView(tableView, heightForHeaderInSection: section);
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true);
        if indexPath.section == 0 {
            self.photoClicked()
        } else {
            if let vc = UIStoryboard(name: "Account", bundle: nil).instantiateViewController(withIdentifier: "DisplayNameViewController") as? DisplayNameViewController {
                vc.account = self.account
                self.navigationController?.pushViewController(vc, animated: true)
            }
            
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func showAvatarSpinner(show: Bool) {
        DispatchQueue.main.async {
            self.isUpdatingAvatar = show
            self.tableView.reloadData()
        }
    }
    
    @objc func photoClicked() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet);
            alert.addAction(UIAlertAction(title: "Take photo", style: .default, handler: { (action) in
                self.selectPhoto(.camera);
            }));
            alert.addAction(UIAlertAction(title: "Select photo", style: .default, handler: { (action) in
                self.selectPhoto(.photoLibrary);
            }));
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil));
            let cell = self.tableView(tableView, cellForRowAt: IndexPath(row: 0, section: 0)) as! VCardAvatarEditCell;
            alert.popoverPresentationController?.sourceView = cell.avatarView;
            alert.popoverPresentationController?.sourceRect = cell.avatarView!.bounds;
            present(alert, animated: true, completion: nil);
        } else {
            selectPhoto(.photoLibrary);
        }
    }
    
    func selectPhoto(_ source: UIImagePickerController.SourceType) {
        picker.delegate = self;
        picker.allowsEditing = true;
        picker.sourceType = source;
        present(picker, animated: true, completion: nil);
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard var photo = (info[UIImagePickerController.InfoKey.editedImage] as? UIImage) else {
            print("no image available!");
            return;
        }
        
        // scalling photo to max of 180px
        var size: CGSize! = nil;
        if photo.size.height > photo.size.width {
            size = CGSize(width: (photo.size.width/photo.size.height) * 180, height: 180);
        } else {
            size = CGSize(width: 180, height: (photo.size.height/photo.size.width) * 180);
        }
        UIGraphicsBeginImageContextWithOptions(size, false, 0);
        photo.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height));
        photo = UIGraphicsGetImageFromCurrentImageContext()!;
        UIGraphicsEndImageContext();
        
        // saving photo
        let data = photo.pngData()
        
        if let data = data {
            if data.count > 72000 { // 72KB
                MediaHelper.resizeTo(image: photo, targetBytes: 72000) { image in
                    if let image = image, let data = image.pngData() {
                        self.showAvatarSpinner(show: true)
                        self.publishAvatar(data: data)
                        self.avatarImage = photo
                        self.tableView.reloadData()
                    } else {
                        print("failed to resize")
                    }
                }
            } else {
                self.showAvatarSpinner(show: true)
                self.publishAvatar(data: data)
                self.avatarImage = photo
                self.tableView.reloadData()
            }
        }
            
        picker.dismiss(animated: true, completion: nil);
        
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil);
    }
    
    func publishAvatar(data: Data) {
        if let client = self.xmppService.getClient(forJid: self.account) {
            if let pepUserAvatarModule:PEPUserAvatarModule = client.modulesManager.getModule(PEPUserAvatarModule.ID) {
                if pepUserAvatarModule.isPepAvailable {
                    
                    let question = UIAlertController(title: nil, message: "Do you wish to publish this photo as avatar?", preferredStyle: .actionSheet)
                    
                    question.addAction(UIAlertAction(title: "Yes", style: .default, handler: { (action) in
                        
                        pepUserAvatarModule.publishAvatar(data: data, mimeType: "image/png", onSuccess: {
                            
                            self.showAvatarSpinner(show: false)
                            self.publishAvatarHash(data: data, client: client)
                            
                            }, onError: { (errorCondition, pubsubErrorCondition) in
                                DispatchQueue.main.async {
                                    let alert = UIAlertController(title: "Error", message: "User avatar publication failed.\nReason: " + ((pubsubErrorCondition?.rawValue ?? errorCondition?.rawValue) ?? "unknown"), preferredStyle: .alert);
                                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: {action in
                                        
                                        self.showAvatarSpinner(show: false)
                                    }));
                                    self.present(alert, animated: true, completion: nil);
                                }
                                print("PEP: user avatar publication failed", errorCondition ?? "nil", pubsubErrorCondition ?? "nil");
                        })
                    }));
                    question.addAction(UIAlertAction(title: "No", style: .cancel, handler: { action in
                        self.showAvatarSpinner(show: false)
                    }));
                    
                    let cell = self.tableView(tableView, cellForRowAt: IndexPath(row: 0, section: 0)) as! VCardAvatarEditCell;
                    question.popoverPresentationController?.sourceView = cell.avatarView;
                    question.popoverPresentationController?.sourceRect = cell.avatarView!.bounds;

                    DispatchQueue.main.async {
                        self.present(question, animated: true, completion: nil);
                    }
                }
            }
        }
    }
    
    func publishAvatarHash(data: Data, client: XMPPClient) {
        let avatarHash = Digest.sha1.digest(toHex: data)
        let presenceModule: PresenceModule = client.modulesManager.getModule(PresenceModule.ID)!
        let x = Element(name: "x", xmlns: "vcard-temp:x:update")
        x.addChild(Element(name: "photo", cdata: avatarHash))
        presenceModule.setPresence(show: .online, status: nil, priority: nil, additionalElements: [x])
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKey(_ input: UIImagePickerController.InfoKey) -> String {
	return input.rawValue
}
