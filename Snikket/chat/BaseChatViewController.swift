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
    
    var sendMessageButton: UIButton?;
    
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

        print("tableView.constraints:", self.view.constraints)
        if let bottomTableViewConstraint = self.view.constraints.first(where: { $0.firstAnchor == containerView.bottomAnchor || $0.secondAnchor == containerView.bottomAnchor }) {
            bottomTableViewConstraint.isActive = false;
            self.view.removeConstraint(bottomTableViewConstraint);
        }
        
        NSLayoutConstraint.activate([
            chatViewInputBar.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            chatViewInputBar.topAnchor.constraint(equalTo: containerView.bottomAnchor),
            chatViewInputBar.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            chatViewInputBar.trailingAnchor.constraint(equalTo: self.view.trailingAnchor)
        ]);

        chatViewInputBar.setNeedsLayout();
                
        chatViewInputBar.delegate = self;
        
        let sendMessageButton = UIButton(type: .custom);
        sendMessageButton.contentEdgeInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4);
        if #available(iOS 13.0, *) {
            sendMessageButton.setImage(UIImage(systemName: "paperplane.fill"), for: .normal);
            NSLayoutConstraint.activate([
                sendMessageButton.widthAnchor.constraint(equalTo: sendMessageButton.heightAnchor),
                sendMessageButton.heightAnchor.constraint(equalToConstant: 30)
            ]);
        } else {
            NSLayoutConstraint.activate([
                sendMessageButton.widthAnchor.constraint(equalTo: sendMessageButton.heightAnchor),
                sendMessageButton.heightAnchor.constraint(equalToConstant: 30)
            ]);
            sendMessageButton.setImage(UIImage(named: "send"), for: .normal);
        }
        sendMessageButton.addTarget(self, action: #selector(sendMessageClicked(_:)), for: .touchUpInside);
        sendMessageButton.contentMode = .scaleToFill;
        sendMessageButton.tintColor = UIColor(named: "tintColor");

        self.sendMessageButton = sendMessageButton;
        chatViewInputBar.addBottomButton(sendMessageButton);
        
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
    
    func sendAttachment(originalUrl: URL?, uploadedUrl: String, appendix: ChatAttachmentAppendix, completionHandler: (() -> Void)?) {
        assert(false, "This method should be overridden");
    }
    
    func messageTextCleared() {
        self.correctedMessageOriginId = nil;
    }
    
    @objc func sendMessageClicked(_ sender: Any) {
        self.sendMessage();
    }
    
}

class ChatViewInputBar: UIView, UITextViewDelegate, NSTextStorageDelegate {
    
    @IBInspectable public var fontSize: CGFloat = 14.0;
    
    public let blurView: UIVisualEffectView = {
        var blurEffect = UIBlurEffect(style: .prominent);
        if #available(iOS 13.0, *) {
            blurEffect = UIBlurEffect(style: .systemMaterial);
        }
        let view = UIVisualEffectView(effect: blurEffect);
        view.translatesAutoresizingMaskIntoConstraints = false;
        return view;
    }();
    
    public let bottomStackView: UIStackView = {
        let view = UIStackView();
        view.translatesAutoresizingMaskIntoConstraints = false;
        view.axis = .horizontal;
        view.alignment = .center;
        view.semanticContentAttribute = .forceRightToLeft;
        view.distribution = .fillProportionally
        view.spacing = 7;
        view.setContentHuggingPriority(.defaultHigh, for: .horizontal);
        view.setContentCompressionResistancePriority(.defaultHigh, for: .vertical);
        return view;
    }();
    
    public let attachmentButton: UIButton = {
        let button = UIButton()
        button.setTitle("", for: .normal)
        if #available(iOS 13.0, *) {
            button.setBackgroundImage(UIImage(systemName: "plus"), for: .normal)
        } else {
            button.setBackgroundImage(UIImage(named: "plus"), for: .normal)
        }
        button.tintColor = .darkGray
        button.imageView?.contentMode = .scaleToFill
        button.translatesAutoresizingMaskIntoConstraints = false;
        button.addTarget(self, action: #selector(attachmentTapped), for: .touchUpInside)
        return button
    }()
    
    public let inputTextView: UITextView = {
        let layoutManager = MessageTextView.CustomLayoutManager();
        let textContainer = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude));
        textContainer.widthTracksTextView = true;
        let textStorage = NSTextStorage();
        textStorage.addLayoutManager(layoutManager);
        layoutManager.addTextContainer(textContainer);
        
        let view = UITextView(frame: .zero, textContainer: textContainer);
        if #available(iOS 13.0, *) {
            view.usesStandardTextScaling = false;
        }
        view.isOpaque = true;
        view.backgroundColor = UIColor(named: "messageInputBackground")
        view.layer.cornerRadius = 20
        view.textContainerInset.left = 7
        view.translatesAutoresizingMaskIntoConstraints = false;
        view.layer.masksToBounds = true;
//        view.delegate = self;
        view.isScrollEnabled = false;
        view.font = UIFont.systemFont(ofSize: UIFont.systemFontSize + 4);
        if Settings.SendMessageOnReturn.getBool() {
            view.returnKeyType = .send;
        } else {
            view.returnKeyType = .default;
        }
        view.setContentHuggingPriority(.defaultHigh, for: .horizontal);
        view.setContentCompressionResistancePriority(.defaultHigh, for: .vertical);
        return view;
    }()
    
    public let placeholderLabel: UILabel = {
        let view = UILabel();
        view.numberOfLines = 0;
        if #available(iOS 13.0, *) {
            view.textColor = UIColor.label.withAlphaComponent(0.4);
        } else {
            view.textColor = UIColor.darkGray;
        }
        view.font = UIFont.systemFont(ofSize: UIFont.systemFontSize + 4);
        view.text = "Enter message...";
        view.backgroundColor = .clear;
        view.translatesAutoresizingMaskIntoConstraints = false;
        return view;
    }();
    
    var placeholder: String? {
        get {
            return placeholderLabel.text;
        }
        set {
            placeholderLabel.text = newValue;
        }
    }
    
    var text: String? {
        get {
            return inputTextView.text;
        }
        set {
            inputTextView.text = newValue ?? "";
            placeholderLabel.isHidden = !inputTextView.text.isEmpty;
        }
    }
    
    weak var delegate: ChatViewInputBarDelegate?;
    
    convenience init() {
        self.init(frame: CGRect(origin: .zero, size: CGSize(width: 100, height: 30)));
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame);
        self.setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder);
        setup();
    }
        
    func setup() {
        inputTextView.textStorage.delegate = self;
        translatesAutoresizingMaskIntoConstraints = false;
        isOpaque = false;
        setContentHuggingPriority(.defaultHigh, for: .horizontal);
        setContentCompressionResistancePriority(.defaultHigh, for: .vertical);
        addSubview(blurView);
        addSubview(attachmentButton)
        addSubview(inputTextView);
        addSubview(bottomStackView);
        NSLayoutConstraint.activate([
            attachmentButton.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 6),
            attachmentButton.trailingAnchor.constraint(equalTo: inputTextView.leadingAnchor, constant: -6),
            attachmentButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor,constant: 13),
            attachmentButton.widthAnchor.constraint(equalToConstant: 25),
            attachmentButton.heightAnchor.constraint(equalToConstant: 25),
            
            blurView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            blurView.topAnchor.constraint(equalTo: self.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            
            //inputTextView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 6),
            inputTextView.trailingAnchor.constraint(equalTo: bottomStackView.leadingAnchor, constant: -3),
            inputTextView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 6),
            inputTextView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -6),
            
            //bottomStackView.leadingAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.leadingAnchor, constant: 10),
            //bottomStackView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: 0)
            bottomStackView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -10),
            bottomStackView.topAnchor.constraint(equalTo: inputTextView.topAnchor, constant: 5),
        ]);
        inputTextView.addSubview(placeholderLabel);
        NSLayoutConstraint.activate([
            inputTextView.leadingAnchor.constraint(equalTo: placeholderLabel.leadingAnchor, constant: -10),
            inputTextView.trailingAnchor.constraint(equalTo: placeholderLabel.trailingAnchor, constant: 4),
            inputTextView.centerYAnchor.constraint(equalTo: placeholderLabel.centerYAnchor),
            inputTextView.topAnchor.constraint(equalTo: placeholderLabel.topAnchor),
            inputTextView.bottomAnchor.constraint(equalTo: placeholderLabel.bottomAnchor)
        ]);
        inputTextView.delegate = self;
    }
    
    override func layoutIfNeeded() {
        super.layoutIfNeeded();
        inputTextView.layoutIfNeeded();
    }
    
    override func resignFirstResponder() -> Bool {
        let val = super.resignFirstResponder();
        return val || inputTextView.resignFirstResponder();
    }
    
    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = textView.hasText;
    }
        
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            print("enter detected");
            if inputTextView.returnKeyType == .send {
                delegate?.sendMessage();
                return false;
            }
        }
        if textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            delegate?.messageTextCleared();
        }
        return true;
    }
        
    func textViewDidEndEditing(_ textView: UITextView) {
        textView.resignFirstResponder();
    }

    func addBottomButton(_ button: UIButton) {
        bottomStackView.addArrangedSubview(button);
    }
    
    func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorage.EditActions, range editedRange: NSRange, changeInLength delta: Int) {
        let fullRange = NSRange(0..<textStorage.length);
        textStorage.fixAttributes(in: fullRange);
        //textStorage.setAttributes([.font: self.font!], range: fullRange);
        if #available(iOS 13.0, *) {
            textStorage.addAttributes([.foregroundColor: UIColor.label], range: fullRange);
        } else {
            textStorage.addAttributes([.foregroundColor: UIColor.black], range: fullRange);
        }
        
        if Settings.EnableMarkdownFormatting.bool() {
            Markdown.applyStyling(attributedString: textStorage, font: UIFont.systemFont(ofSize: fontSize + 4), showEmoticons: false);
        }
    }
    
    @objc func attachmentTapped() {
        delegate?.presentSheet()
    }
}

protocol ChatViewInputBarDelegate: class {
    
    func sendMessage();
    
    func messageTextCleared();
    
    func presentSheet()
    
}
