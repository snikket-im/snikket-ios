//
// BaseChatViewController.swift
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
import UserNotifications
import TigaseSwift

class BaseChatViewController: UIViewController, UITextViewDelegate, ChatViewInputBarDelegate {

    @IBOutlet var containerView: UIView!;
    
    var conversationLogController: ConversationLogController? {
        didSet {
            self.conversationLogController?.chat = self.chat;
        }
    }
    
    @IBInspectable var animateScrollToBottom: Bool = true;
    
    var chat: DBChatProtocol! {
        didSet {
            conversationLogController?.chat = chat;
        }
    }
        
    var account:BareJID!;
    var jid:BareJID!;
    
    private(set) var correctedMessageOriginId: String?;
    
    var progressBar: UIProgressView?;

    var askMediaQuality: Bool = false;
    
    var messageText: String? {
        get {
            return chatViewInputBar.text;
        }
        set {
            chatViewInputBar.text = newValue;
            if newValue == nil {
                self.correctedMessageOriginId = nil;
            }
        }
    }
        
    let chatViewInputBar = ChatViewInputBar();
    
    func conversationTableViewDelegate() -> UITableViewDelegate? {
        return nil;
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        chatViewInputBar.placeholder = "New Message";

        navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem;
        navigationItem.leftItemsSupplementBackButton = true;

        self.view.addSubview(chatViewInputBar);

        //print("tableView.constraints:", self.view.constraints)
        
        if let bottomTableViewConstraint = self.view.constraints.first(where: { $0.firstAnchor == containerView.bottomAnchor || $0.secondAnchor == containerView.bottomAnchor }) {
            bottomTableViewConstraint.isActive = false;
            self.view.removeConstraint(bottomTableViewConstraint);
        }
        
        NSLayoutConstraint.activate([
            chatViewInputBar.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            chatViewInputBar.topAnchor.constraint(equalTo: containerView.bottomAnchor),
            chatViewInputBar.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            chatViewInputBar.trailingAnchor.constraint(equalTo: self.view.trailingAnchor)
            //chatViewInputBar.heightAnchor.constraint(equalToConstant: 60)
        ]);

        chatViewInputBar.setNeedsLayout();
                
        chatViewInputBar.delegate = self;
        
        setColors();
        NotificationCenter.default.addObserver(self, selector: #selector(chatClosed(_:)), name: DBChatStore.CHAT_CLOSED, object: chat);
    }

    override func didReceiveMemoryWarning() {
        
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
   
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destination = segue.destination as? ConversationLogController {
            self.conversationLogController = destination;
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
        
        if self.messageText?.isEmpty ?? true {
            XmppService.instance.dbChatStore.messageDraft(for: account, with: jid) { (text) in
                DispatchQueue.main.async {
                    self.messageText = text;
                }
            }
        }
//        chatViewInputBar.becomeFirstResponder();
        NotificationCenter.default.addObserver(self, selector: #selector(ChatViewController.keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil);
        NotificationCenter.default.addObserver(self, selector: #selector(ChatViewController.keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil);
        
        animate();
        
    }
    
    func presentSheet() {
        let alertController = UIAlertController()
        let camera = UIAlertAction(title: "Camera", style: .default) { (action: UIAlertAction!) in
            self.selectPhoto(.camera)
        }
        let photo = UIAlertAction(title: "Photo & Video Library", style: .default) { (action: UIAlertAction!) in
            if #available(iOS 14.0, *) {
                self.selectPhotoFromLibrary();
            } else {
                self.selectPhoto(.photoLibrary)
            }
        }
        let document = UIAlertAction(title: "Document", style: .default) { (action: UIAlertAction!) in
            self.selectFile()
        }
        let cancel = UIAlertAction(title: "Cancel", style: .cancel) { (action: UIAlertAction!) in
        }
        
        let cameraImage = UIImage(named: "camera")
        if let icon = cameraImage?.imageWithSize(scaledToSize: CGSize(width: 28, height: 28)) {
            camera.setValue(icon, forKey: "image")
        }
        
        let photoImage = UIImage(named: "photo")
        if let icon = photoImage?.imageWithSize(scaledToSize: CGSize(width: 28, height: 28)) {
            photo.setValue(icon, forKey: "image")
        }
        
        
        if #available(iOS 13.0, *) {
            let documentImage = UIImage(systemName: "arrow.up.doc");
            if let icon = documentImage?.imageWithSize(scaledToSize: CGSize(width: 28, height: 28)) {
                document.setValue(icon, forKey: "image")
            }
        } else {
            photo.setValue(UIImage(named: "arrow.up.doc"), forKey: "image")
        }
        
        camera.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
        camera.setValue(UIColor.darkGray, forKey: "titleTextColor")
        photo.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
        photo.setValue(UIColor.darkGray, forKey: "titleTextColor")
        document.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
        document.setValue(UIColor.darkGray, forKey: "titleTextColor")
        
        alertController.addAction(camera)
        alertController.addAction(photo)
        alertController.addAction(document)
        alertController.addAction(cancel)
        self.present(alertController, animated: true, completion: nil)
    }
    
    @objc func chatClosed(_ notification: Notification) {
        DispatchQueue.main.async {
            if let navigationController = self.navigationController {
                if navigationController.viewControllers.count == 1 {
                    self.showDetailViewController(UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "emptyDetailViewController"), sender: self);
                } else {
                    navigationController.popToRootViewController(animated: true);
                }
            } else {
                self.dismiss(animated: true, completion: nil);
            }
        }
    }
    
    private func animate() {
        guard let coordinator = self.transitionCoordinator else {
            return;
        }
        coordinator.animate(alongsideTransition: { [weak self] context in
            self?.setColors();
        }, completion: nil);
    }
    
    private func setColors() {
        navigationController?.navigationBar.barTintColor = UIColor(named: "chatslistBackground");
        navigationController?.navigationBar.tintColor = UIColor(named: "tintColor");
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated);
        let accountStr = account.stringValue.lowercased();
        let jidStr = jid.stringValue.lowercased();
        UNUserNotificationCenter.current().getDeliveredNotifications { (notifications) in
            var toRemove = [String]();
            for notification in notifications {
                if (notification.request.content.userInfo["account"] as? String)?.lowercased() == accountStr && (notification.request.content.userInfo["sender"] as? String)?.lowercased() == jidStr {
                    toRemove.append(notification.request.identifier);
                }
            }
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: toRemove);
//            self.xmppService.dbChatHistoryStore.markAsRead(for: self.account, with: self.jid);
        }
        print("size:", chatViewInputBar.intrinsicContentSize, chatViewInputBar.frame.size);
    }
        
    override func viewWillDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil);
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil);
        super.viewWillDisappear(animated);
        if let account = self.account, let jid = self.jid {
            XmppService.instance.dbChatStore.storeMessage(draft: messageText, for: account, with: jid);
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        //NotificationCenter.default.removeObserver(self);
        super.viewDidDisappear(animated);
    }
    
    @objc func keyboardWillShow(_ notification: NSNotification) {
        if let userInfo = notification.userInfo {
            if let endRect = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
                guard endRect.height != 0 && endRect.size.width != 0 else {
                    return;
                }
                let window: UIView? = self.view.window;
                let keyboard = self.view.convert(endRect, from: window);
                let height = self.view.frame.size.height;
                let hasExternal = (keyboard.origin.y + keyboard.size.height) > height;
                
                let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as! TimeInterval;
                let curve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as! UInt;
                UIView.animate(withDuration: duration, delay: 0.0, options: [UIView.AnimationOptions(rawValue: curve), UIView.AnimationOptions.beginFromCurrentState], animations: {
                    if !hasExternal {
                        self.keyboardHeight = endRect.origin.y == 0 ? endRect.size.width : endRect.size.height;
                    } else {
                        self.keyboardHeight = height - keyboard.origin.y;
                    }
                    }, completion: nil);
            }
        }
    }
    
    @objc func keyboardWillHide(_ notification: NSNotification) {
        let curve = notification.userInfo![UIResponder.keyboardAnimationCurveUserInfoKey] as! UInt;
        UIView.animate(withDuration: notification.userInfo![UIResponder.keyboardAnimationDurationUserInfoKey] as! TimeInterval, delay: 0.0, options: [UIView.AnimationOptions(rawValue: curve), UIView.AnimationOptions.beginFromCurrentState], animations: {
            self.keyboardHeight = 0;
            }, completion: nil);
    }
    
    var keyboardHeight: CGFloat = 0 {
        didSet {
            print("setting keyboard height:", keyboardHeight);
            self.view.constraints.first(where: { $0.firstAnchor == self.view.bottomAnchor || $0.secondAnchor == self.view.bottomAnchor })?.constant = keyboardHeight * -1;
        }
    }
    
    @IBAction func tableViewClicked(_ sender: AnyObject) {
        _ = self.chatViewInputBar.resignFirstResponder();
    }
        
    func startMessageCorrection(message: String, originId: String) {
        self.messageText = message;
        self.correctedMessageOriginId = originId;
    }
    
    func sendMessage() {
        assert(false, "This method should be overridden");
    }
    
    func sendAudioMessage(fileUrl: URL) {
        uploadFile(url: fileUrl, filename: "recording.m4a", deleteSource: true)
        //assert(false, "This method should be overridden");
    }
    
    func sendAttachment(originalUrl: URL?, uploadedUrl: String, appendix: ChatAttachmentAppendix, completionHandler: (() -> Void)?) {
        assert(false, "This method should be overridden");
    }
    
    func messageTextCleared() {
        self.correctedMessageOriginId = nil;
    }
    
    func cameraButtonTapped() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            self.selectPhoto(.camera)
        }
    }
    
    @objc func sendMessageClicked(_ sender: Any) {
        self.sendMessage();
    }
    
}
