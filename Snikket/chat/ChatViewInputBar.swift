//
//  ChatViewInputBar.swift
//  Snikket
//
//  Created by Khalid Khan on 8/20/21.
//  Copyright © 2021 Snikket. All rights reserved.
//

import AVFoundation
import UIKit

class ChatViewInputBar: UIView, UITextViewDelegate, NSTextStorageDelegate {
    
    @IBInspectable public var fontSize: CGFloat = 14.0;
    static var isRecordingAllowed = true
    
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
    
    public let sendMessageButton: UIButton = {
        let button = UIButton(type: .custom);
        button.contentEdgeInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4);
        if #available(iOS 13.0, *) {
            button.setImage(UIImage(systemName: "paperplane.fill"), for: .normal);
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalTo: button.heightAnchor),
                button.heightAnchor.constraint(equalToConstant: 30)
            ]);
        } else {
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalTo: button.heightAnchor),
                button.heightAnchor.constraint(equalToConstant: 30)
            ]);
            button.setImage(UIImage(named: "send"), for: .normal);
        }
        button.addTarget(self, action: #selector(sendMessage), for: .touchUpInside);
        button.contentMode = .scaleToFill;
        button.tintColor = UIColor(named: "tintColor");
        button.isHidden = true
        return button
    }()
    
    public let cameraButton: UIButton = {
        let button = UIButton()
        if #available(iOS 13.0, *) {
            button.setImage(UIImage(systemName: "camera"), for: .normal)
        } else {
            button.setImage(UIImage(named: "camera"), for: .normal)
        }
        button.tintColor = UIColor(named: "tintColor")
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalTo: button.heightAnchor).isActive = true
        button.heightAnchor.constraint(equalToConstant: 30).isActive = true
        return button
    }()
    
    public let micButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "mic"), for: .normal)
        button.tintColor = UIColor(named: "tintColor")
        button.addTarget(self, action: #selector(micTapped), for: .touchUpInside)
        //button.addTarget(self, action: #selector(presentRecordPermission), for: .touchDown)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalTo: button.heightAnchor).isActive = true
        button.heightAnchor.constraint(equalToConstant: 30).isActive = true
        return button
    }()
    
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
        return button
    }()
    
    public let bottomLeftView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.clipsToBounds = true
        return view
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
    
    var cancelRecordingButton: UIButton!
    var voiceRecordingView: UIView!
    var voiceLockedView: UIView!
    var recordingTimeLabel: UILabel!
    
    var leftBottomViewWidthConstraint: NSLayoutConstraint!
    var voiceRecordingViewWidthConstraint: NSLayoutConstraint!
    var voiceLockHeightConstraint: NSLayoutConstraint!
    
    var audioFileUrl: URL?
    var isLocked = false
    var recordingSession: AVAudioSession!
    var audioRecorder: AVAudioRecorder!
    
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
        inputTextView.delegate = self
        inputTextView.textStorage.delegate = self;
        translatesAutoresizingMaskIntoConstraints = false;
        isOpaque = false;
        setContentHuggingPriority(.defaultHigh, for: .horizontal);
        setContentCompressionResistancePriority(.defaultHigh, for: .vertical);
        
        let longTap = UILongPressGestureRecognizer(target: self, action: #selector(self.handleLongTapOnMic(_:)))
        micButton.addGestureRecognizer(longTap)
        longTap.delegate = self
        let pan = UIPanGestureRecognizer(target: self, action: #selector(self.handlePan(_:)))
        micButton.addGestureRecognizer(pan)
        
        attachmentButton.addTarget(self, action: #selector(attachmentTapped), for: .touchUpInside)
        cameraButton.addTarget(self, action: #selector(cameraTapped), for: .touchUpInside)
        
        self.micTapErrorView = makeMicErrorView()
        self.voiceRecordingView = makeVoiceRecordingView()
        self.voiceLockedView = makeVoiceRecordingLockView()
        addBottomButton(self.sendMessageButton)
        addBottomButton(self.micButton)
        addBottomButton(self.cameraButton)
        
        addSubview(blurView)
        addSubview(bottomStackView)
        addSubview(bottomLeftView)
        addSubview(voiceRecordingView)
        
        bottomLeftView.addSubview(attachmentButton)
        bottomLeftView.addSubview(inputTextView)
        
        NSLayoutConstraint.activate([
            
            bottomLeftView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            bottomLeftView.topAnchor.constraint(equalTo: self.topAnchor),
            bottomLeftView.bottomAnchor.constraint(equalTo: self.safeAreaLayoutGuide.bottomAnchor),
            bottomLeftView.trailingAnchor.constraint(equalTo: voiceRecordingView.leadingAnchor),
            
            voiceRecordingView.topAnchor.constraint(equalTo: self.topAnchor),
            voiceRecordingView.trailingAnchor.constraint(equalTo: bottomStackView.leadingAnchor),
            voiceRecordingView.bottomAnchor.constraint(equalTo: self.safeAreaLayoutGuide.bottomAnchor),
            voiceRecordingView.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),
            
            attachmentButton.leadingAnchor.constraint(equalTo: bottomLeftView.leadingAnchor, constant: 6),
            attachmentButton.trailingAnchor.constraint(equalTo: inputTextView.leadingAnchor, constant: -6),
            attachmentButton.topAnchor.constraint(equalTo: bottomLeftView.topAnchor,constant: 13),
            attachmentButton.widthAnchor.constraint(equalToConstant: 25),
            attachmentButton.heightAnchor.constraint(equalToConstant: 25),
            
            inputTextView.trailingAnchor.constraint(equalTo: bottomLeftView.trailingAnchor, constant: -3),
            inputTextView.topAnchor.constraint(equalTo: bottomLeftView.topAnchor, constant: 6),
            inputTextView.bottomAnchor.constraint(equalTo: bottomLeftView.bottomAnchor, constant: -6),
            
            bottomStackView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -10),
            bottomStackView.topAnchor.constraint(equalTo: inputTextView.topAnchor, constant: 5),
            
            blurView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            blurView.topAnchor.constraint(equalTo: self.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
        ]);
        
        inputTextView.addSubview(placeholderLabel);
        NSLayoutConstraint.activate([
            inputTextView.leadingAnchor.constraint(equalTo: placeholderLabel.leadingAnchor, constant: -10),
            inputTextView.trailingAnchor.constraint(equalTo: placeholderLabel.trailingAnchor, constant: 4),
            inputTextView.centerYAnchor.constraint(equalTo: placeholderLabel.centerYAnchor),
            inputTextView.topAnchor.constraint(equalTo: placeholderLabel.topAnchor),
            inputTextView.bottomAnchor.constraint(equalTo: placeholderLabel.bottomAnchor)
        ]);
        
        leftBottomViewWidthConstraint = bottomLeftView.widthAnchor.constraint(equalToConstant: 0)
        voiceRecordingViewWidthConstraint = voiceRecordingView.widthAnchor.constraint(equalToConstant: 0)
        voiceRecordingViewWidthConstraint.isActive = true
    }
    
    override func layoutIfNeeded() {
        super.layoutIfNeeded();
        inputTextView.layoutIfNeeded();
    }
    
    override func resignFirstResponder() -> Bool {
        let val = super.resignFirstResponder();
        return val || inputTextView.resignFirstResponder();
    }
    
    func recordingPermission() {
        recordingSession = AVAudioSession.sharedInstance()

        do {
            try recordingSession.setCategory(.playAndRecord, mode: .default)
            try recordingSession.setActive(true)
            recordingSession.requestRecordPermission() { allowed in
                DispatchQueue.main.async {
                    if !allowed {
                        ChatViewInputBar.isRecordingAllowed = false
                    }
                }
            }
        } catch {
            // failed to record!
        }
    }
    
    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = textView.hasText;
        
        let text = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if text != "" {
            self.sendMessageButton.alpha = 1
            self.cameraButton.alpha = 0
            self.micButton.alpha = 0
        } else {
            self.sendMessageButton.alpha = 0
            self.cameraButton.alpha = 1
            self.micButton.alpha = 1
        }
        
        UIView.animate(withDuration: 0.1, delay: 0.0, options: .curveEaseOut) {
            if text != "" {
                self.sendMessageButton.isHidden = false
                self.cameraButton.isHidden = true
                self.micButton.isHidden = true
            } else {
                self.sendMessageButton.isHidden = true
                self.cameraButton.isHidden = false
                self.micButton.isHidden = false
            }
        } completion: { success in
            if text != "" {
                self.sendMessageButton.isHidden = false
                self.cameraButton.isHidden = true
                self.micButton.isHidden = true
            } else {
                self.sendMessageButton.isHidden = true
                self.cameraButton.isHidden = false
                self.micButton.isHidden = false
            }
        }
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
    
    @objc func sendMessage() {
        if audioRecorder != nil, audioRecorder.currentTime > 2, let fileUrl = audioFileUrl {
            stopRecording()
            showRecordingView(show: false)
            self.sendMessageButton.isHidden = true
            self.micButton.isHidden = false
            delegate?.sendAudioMessage(fileUrl: fileUrl)
            print("sending audio message")
        }else {
            delegate?.sendMessage()
            self.sendMessageButton.isHidden = true
            self.micButton.isHidden = false
            self.cameraButton.isHidden = false
            self.micButton.alpha = 1
            self.cameraButton.alpha = 1
        }
        
    }
    
    @objc func cameraTapped() {
        delegate?.cameraButtonTapped()
    }
    
    @objc func micTapped() {
        guard let micTapErrorView = micTapErrorView else { return }
        
        if micTapErrorView.isDescendant(of: self) {
            return
        } else {
            self.addSubview(micTapErrorView)
            self.bringSubviewToFront(micTapErrorView)
            micTapErrorView.trailingAnchor.constraint(equalTo: self.bottomStackView.trailingAnchor).isActive = true
            micTapErrorView.bottomAnchor.constraint(equalTo: self.bottomStackView.topAnchor, constant: -8).isActive = true
            
            DispatchQueue.main.asyncAfter(deadline: .now()+2) {
                micTapErrorView.removeFromSuperview()
            }
        }
    }
    
    var micTapErrorView: UIView?
    var recordingStartTime = 0.0
    
    var closeView: UIImageView = {
        let closeIV = UIImageView()
        closeIV.translatesAutoresizingMaskIntoConstraints = false
        closeIV.image = UIImage(named: "xmark.circle.fill")
        closeIV.tintColor = .white
        closeIV.widthAnchor.constraint(equalToConstant: 18).isActive = true
        closeIV.heightAnchor.constraint(equalToConstant: 18).isActive = true
        closeIV.isUserInteractionEnabled = true
        return closeIV
    }()
    
    func makeMicErrorView() -> UIView {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "hold to record, release to send"
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 15)
        label.isUserInteractionEnabled = true
        
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 5
        view.layer.masksToBounds = true
        view.backgroundColor = .darkGray
        view.isUserInteractionEnabled = true
        
        view.addSubview(label)
        label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10).isActive = true
        label.topAnchor.constraint(equalTo: view.topAnchor, constant: 5).isActive = true
        label.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -5).isActive = true
        
        view.addSubview(closeView)
        closeView.centerYAnchor.constraint(equalTo: label.centerYAnchor).isActive = true
        closeView.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 10).isActive = true
        closeView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10).isActive = true
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
        closeView.addGestureRecognizer(tap)
        
        return view
    }
    
    func makeVoiceRecordingView() -> UIView {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.clipsToBounds = true
        
        let micImage = UIImageView(image: UIImage(named: "mic.fill"))
        micImage.translatesAutoresizingMaskIntoConstraints = false
        micImage.tintColor = .red
        micImage.contentMode = .scaleAspectFit
        micImage.widthAnchor.constraint(equalToConstant: 30).isActive = true
        micImage.heightAnchor.constraint(equalToConstant: 30).isActive = true
        
        UIView.animate(withDuration: 1.0,
                              delay: 0,
                            options: [.repeat, .autoreverse],
                         animations: { micImage.alpha = 0 }
                      )
        
        recordingTimeLabel = UILabel()
        recordingTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        recordingTimeLabel.textColor = .black
        recordingTimeLabel.font = UIFont.systemFont(ofSize: 20)
        recordingTimeLabel.text = "0:00"
        recordingTimeLabel.textAlignment = .left
        recordingTimeLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        cancelRecordingButton = UIButton()
        cancelRecordingButton.translatesAutoresizingMaskIntoConstraints = false
        let slideStr = NSMutableAttributedString(string: "slide to cancel  ")
        let arrowImg = NSTextAttachment()
        arrowImg.image = UIImage(named: "chevron.left")
        arrowImg.bounds = CGRect(x: 0, y: -2, width: 10, height: 15)
        let arrowStr = NSAttributedString(attachment: arrowImg)
        slideStr.append(arrowStr)
        cancelRecordingButton.setAttributedTitle(slideStr, for: .normal)
        cancelRecordingButton.addTarget(self, action: #selector(cancelVoiceRecording), for: .touchUpInside)
        
        view.addSubview(micImage)
        micImage.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10).isActive = true
        micImage.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        
        view.addSubview(recordingTimeLabel)
        recordingTimeLabel.leadingAnchor.constraint(equalTo: micImage.trailingAnchor, constant: 5).isActive = true
        recordingTimeLabel.centerYAnchor.constraint(equalTo: micImage.centerYAnchor).isActive = true
        recordingTimeLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        
        view.addSubview(cancelRecordingButton)
        cancelRecordingButton.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        cancelRecordingButton.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 30).isActive = true
        
        return view
    }
    
    func makeVoiceRecordingLockView() -> UIView {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(named: "messageInputBackground")
        view.clipsToBounds = true
        view.layer.cornerRadius = 25
        
        let lockImage = UIImageView()
        lockImage.translatesAutoresizingMaskIntoConstraints = false
        lockImage.image = UIImage(named: "lock")
        lockImage.tintColor = UIColor(named: "tintColor")
        
        let arrowUp = UIImageView()
        arrowUp.translatesAutoresizingMaskIntoConstraints = false
        arrowUp.image = UIImage(named: "chevron.up")
        
        view.addSubview(lockImage)
        lockImage.topAnchor.constraint(equalTo: view.topAnchor, constant: 15).isActive = true
        lockImage.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        
        view.addSubview(arrowUp)
        arrowUp.topAnchor.constraint(equalTo: lockImage.bottomAnchor, constant: 10).isActive = true
        arrowUp.centerXAnchor.constraint(equalTo: lockImage.centerXAnchor).isActive = true
        
        view.widthAnchor.constraint(equalToConstant: 50).isActive = true
        self.voiceLockHeightConstraint = view.heightAnchor.constraint(equalToConstant: 0)
        self.voiceLockHeightConstraint.isActive = true
        
        self.addSubview(view)
        view.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true
        view.bottomAnchor.constraint(equalTo: self.topAnchor, constant: 30).isActive = true
        
        return view
    }
    
    @objc func handleTap(_ sender: UITapGestureRecognizer? = nil) {
        micTapErrorView?.removeFromSuperview()
    }
    
    func showRecordingView(show: Bool) {
        self.leftBottomViewWidthConstraint.isActive = show
        self.voiceRecordingViewWidthConstraint.isActive = !show
        if show { self.voiceLockHeightConstraint.constant = 150 }
        else {
            self.voiceLockHeightConstraint.constant = 0
            stopRecording()
        }
        self.cameraButton.isHidden = show
        UIView.animate(withDuration: 0.3) {
            self.layoutIfNeeded()
        }
    }
    
    @objc func handleLongTapOnMic(_ sender: UILongPressGestureRecognizer? = nil) {
        guard let sender = sender else { return }
        
        if sender.state == .began {
            recordingPermission()
            
            isLocked = false
            self.recordingStartTime = 0
            self.recordingStartTime = CFAbsoluteTimeGetCurrent()
            self.showRecordingView(show: true)
            self.setRecordingCancelButtonTitle(slideToCancel: true)
            startRecording()
        }
        
        if sender.state == .ended {
            
            if ((CFAbsoluteTimeGetCurrent() - recordingStartTime) < 2), !isLocked {
                showRecordingView(show: false)
            } else if !isLocked {
                sendMessage()
                showRecordingView(show: false)
            }
        }
    }
    
    lazy var initialCenter: CGPoint = {
        let center = self.cancelRecordingButton.center
        return center
    }()
    
    @objc func handlePan(_ sender : UIPanGestureRecognizer) {
        guard sender.view != nil else {return}
        
        let translation = sender.translation(in: sender.view?.superview)
        
        if sender.state != .cancelled, !isLocked {
            let newCenter = CGPoint(x: initialCenter.x + translation.x, y: initialCenter.y)
            self.cancelRecordingButton.center = newCenter

            // moving the cancel button
            let screenWidth = UIScreen.main.bounds.width
            var nPoint = translation.x/screenWidth
            nPoint = 1 - abs(nPoint * 2.5)
            self.cancelRecordingButton.alpha = nPoint
            
            if nPoint < 0.4 {
                showRecordingView(show: false)
            }
            
            // moving the lock view
            let fractionComplete = abs(translation.y/150)
            
            if fractionComplete > 0.8 {
                self.voiceLockHeightConstraint.constant = 0
                self.cancelRecordingButton.alpha = 1
                self.micButton.isHidden = true
                self.sendMessageButton.isHidden = false
                self.sendMessageButton.alpha = 1
                self.isLocked = true
                self.setRecordingCancelButtonTitle(slideToCancel: false)
            }
            
        }
        
        if sender.state == .ended || sender.state == .cancelled {
            self.cancelRecordingButton.center = initialCenter
            self.cancelRecordingButton.alpha = 1.0
        }
    }
    
    func setRecordingCancelButtonTitle(slideToCancel: Bool) {
        if slideToCancel {
            let slideStr = NSMutableAttributedString(string: "slide to cancel  ")
            let arrowImg = NSTextAttachment()
            arrowImg.image = UIImage(named: "chevron.left")
            arrowImg.bounds = CGRect(x: 0, y: -2, width: 10, height: 15)
            let arrowStr = NSAttributedString(attachment: arrowImg)
            slideStr.append(arrowStr)
            cancelRecordingButton.setAttributedTitle(slideStr, for: .normal)
        } else {
            let cancelStr = NSMutableAttributedString(string: "Cancel")
            cancelRecordingButton.setAttributedTitle(cancelStr, for: .normal)
        }
    }
    
    @objc func cancelVoiceRecording() {
        showRecordingView(show: false)
        self.micButton.isHidden = false
        self.sendMessageButton.isHidden = true
        // stop recording
        stopRecording()
        
    }
    
    func startRecording() {
        if audioRecorder != nil {
            showRecordingView(show: false)
            return
        }
        
        audioFileUrl = getAudioFileName()

        guard let audioFileUrl = audioFileUrl else { return }
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: audioFileUrl, settings: settings)
            audioRecorder.delegate = self
            audioRecorder.record()
        } catch {
            print(error.localizedDescription)
        }
        
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if self.audioRecorder != nil {
                DispatchQueue.main.async {
                    self.recordingTimeLabel.text = self.audioRecorder.currentTime.stringTime
                }
            } else {
                timer.invalidate()
            }
        }
    }
    
    func stopRecording() {
        if audioRecorder != nil {
            audioRecorder.stop()
            audioRecorder = nil
        }
    }
    
    func getAudioFileName() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("\(UUID().uuidString).m4a")
        
    }
    
}

extension ChatViewInputBar : AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            print("recording failed")
        }
    }
}

extension ChatViewInputBar : UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
     }
}



protocol ChatViewInputBarDelegate: AnyObject {
    
    func sendMessage()
    
    func sendAudioMessage(fileUrl: URL)
    
    func cameraButtonTapped()
    
    func messageTextCleared();
    
    func presentSheet()
    
}
