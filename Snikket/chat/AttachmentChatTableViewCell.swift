//
// AttachmentChatTableViewCell.swift
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
import MobileCoreServices
import LinkPresentation
import TigaseSwift
import AVKit

class AttachmentChatTableViewCell: BaseChatTableViewCell, UIContextMenuInteractionDelegate {
    
    @IBOutlet var customView: UIView!;
    
    override var backgroundColor: UIColor? {
        didSet {
            customView?.backgroundColor = backgroundColor;
        }
    }
    
    fileprivate var tapGestureRecognizer: UITapGestureRecognizer?;
    fileprivate var longPressGestureRecognizer: UILongPressGestureRecognizer?;
    
    private var item: ChatAttachment?;
    
    private var linkView: UIView? {
        didSet {
//            if let old = oldValue, let new = linkView {
//                guard old != new else {
//                    return;
//                }
//            }
            if let view = oldValue {
                view.removeFromSuperview();
            }
            if let view = linkView {
                view.translatesAutoresizingMaskIntoConstraints = false
                self.customView.addSubview(view);
                if #available(iOS 13.0, *) {
                    view.addInteraction(UIContextMenuInteraction(delegate: self));
                }
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib();
        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapGestureDidFire));
        tapGestureRecognizer?.cancelsTouchesInView = false;
        tapGestureRecognizer?.numberOfTapsRequired = 1;
        customView.addGestureRecognizer(tapGestureRecognizer!);
        
        if #available(iOS 13.0, *) {
            customView.addInteraction(UIContextMenuInteraction(delegate: self));
        } else {
            longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPressGestureDidFire));
            longPressGestureRecognizer?.cancelsTouchesInView = true;
            longPressGestureRecognizer?.delegate = self;
                
            customView.addGestureRecognizer(longPressGestureRecognizer!);
        }
    }
    
    lazy var playButton: UIButton = {
        let playButton = UIButton()
        playButton.setImage(UIImage(named: "play.fill"), for: .normal)
        playButton.setImage(UIImage(named: "pause.fill"), for: .selected)
        playButton.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)
        playButton.translatesAutoresizingMaskIntoConstraints = false
        return playButton
    }()
    lazy var slider: CustomSlider = {
        let slider = CustomSlider()
        slider.setThumbRadius(radius: 15)
        slider.addTarget(self, action: #selector(sliderScrubber(sender:)), for: .valueChanged)
        slider.translatesAutoresizingMaskIntoConstraints = false
        return slider
    }()
    lazy var audioTime: UILabel = {
        let audioTime = UILabel()
        audioTime.text = "00:00"
        audioTime.textColor = UIColor(named: "tintColor")
        audioTime.font = UIFont.systemFont(ofSize: 12)
        audioTime.setContentHuggingPriority(.required, for: .horizontal)
        audioTime.translatesAutoresizingMaskIntoConstraints = false
        return audioTime
    }()
    
    var audioPlayer: AVAudioPlayer?
    var audioTimer: Foundation.Timer?
    var sliderTimer: Foundation.Timer?
    
    func setupAudioCell(item: ChatAttachment) {
        self.customView.backgroundColor = .clear
        self.customView.subviews.forEach { $0.removeFromSuperview() }
        if let gesture = tapGestureRecognizer {
            self.customView.removeGestureRecognizer(gesture)
        }
        
        setupAudioPlayer()
        
        self.customView.addSubview(playButton)
        self.customView.addSubview(slider)
        self.customView.addSubview(audioTime)
        
        let sliderWidth = UIScreen.main.bounds.width * 0.30
        
        NSLayoutConstraint.activate([
            playButton.topAnchor.constraint(equalTo: customView.topAnchor),
            playButton.bottomAnchor.constraint(equalTo: customView.bottomAnchor),
            playButton.leadingAnchor.constraint(equalTo: customView.leadingAnchor),
            playButton.widthAnchor.constraint(equalToConstant: 17),
            playButton.heightAnchor.constraint(equalToConstant: 17),
            
            slider.centerYAnchor.constraint(equalTo: playButton.centerYAnchor),
            slider.leadingAnchor.constraint(equalTo: playButton.trailingAnchor, constant: 10),
            slider.widthAnchor.constraint(equalToConstant: sliderWidth),
            
            audioTime.centerYAnchor.constraint(equalTo: slider.centerYAnchor),
            audioTime.leadingAnchor.constraint(equalTo: slider.trailingAnchor, constant: 10),
            audioTime.trailingAnchor.constraint(equalTo: customView.trailingAnchor, constant: -5)
        ])
    }
    
    func setupAudioPlayer() {
        guard let item = self.item else { return }
        
        let session = AVAudioSession.sharedInstance()

        do {
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            
        }
        
        if let localUrl = DownloadStore.instance.url(for: "\(item.id)") {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: localUrl)
                audioPlayer?.prepareToPlay()
                audioPlayer?.volume = 1.0
                self.audioTime.text = audioPlayer?.duration.stringTime

            }
            catch let error as NSError {
                print(error.localizedDescription)
            }
        }
    }
    
    @objc func playPauseTapped() {
        let isSelected = self.playButton.isSelected
        self.playButton.isSelected = !isSelected
        
            if !isSelected {
                    
                audioTimer = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(updateAudioTime), userInfo: nil, repeats: true)
                sliderTimer = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(updateSlider), userInfo: nil, repeats: true)
                
                audioPlayer?.play()
                
                if let player = self.audioPlayer, let audioTimer = self.audioTimer, let sliderTimer = self.sliderTimer {
                    self.audioPlayerDelegate?.didPlayAudio(audioPlayer: player, audioTimer: audioTimer, sliderTimer: sliderTimer, playButton: self.playButton)
                }
                
            }
            else {
                audioPlayer?.pause()
                self.audioPlayerDelegate?.didStopAudio()
            }
    }
    
    @objc func sliderScrubber(sender: UISlider) {
        guard let player = self.audioPlayer else { return }
        
        let value = Double(sender.value) * player.duration
        player.currentTime = value
    }
    
    @objc func updateSlider() {
        guard let player = self.audioPlayer else {
            sliderTimer?.invalidate()
            return
        }
        if !player.isPlaying {
            sliderTimer?.invalidate()
        }
        
        slider.value = Float(player.currentTime/player.duration)
        
        if slider.value == 0.0, !player.isPlaying {
            self.playButton.isSelected = false
            self.audioPlayerDelegate?.didStopAudio()
        }
    }
    
    @objc func updateAudioTime() {
        guard let player = audioPlayer else {
            audioTimer?.invalidate()
            return
        }
        if !player.isPlaying {
            audioTimer?.invalidate()
            return
        }
        
        let currentTime = Int(player.currentTime)

        let minutes = currentTime/60
        let seconds = currentTime - minutes / 60

        audioTime.text = NSString(format: "%02d:%02d", minutes,seconds) as String
    }
        
    func set(attachment item: ChatAttachment) {
        self.item = item;
        self.customView.subviews.forEach { view in
            view.removeFromSuperview()
        }
        
        super.set(item: item);
        
        self.customView?.isOpaque = true;
        self.customView?.backgroundColor = self.backgroundColor;
        
        if let mime = item.appendix.mimetype, mime.contains("audio") {
            setupAudioCell(item: item)
            return
        }
        
        if let localUrl = DownloadStore.instance.url(for: "\(item.id)") {
            documentController = UIDocumentInteractionController(url: localUrl);
            let attachmentInfo = (self.linkView as? AttachmentInfoView) ?? AttachmentInfoView(frame: .zero);
            attachmentInfo.translatesAutoresizingMaskIntoConstraints = false
            self.linkView = attachmentInfo;
            NSLayoutConstraint.activate([
                attachmentInfo.leadingAnchor.constraint(equalTo: customView.leadingAnchor),
                attachmentInfo.trailingAnchor.constraint(equalTo: customView.trailingAnchor),
                attachmentInfo.topAnchor.constraint(equalTo: customView.topAnchor),
                attachmentInfo.bottomAnchor.constraint(equalTo: customView.bottomAnchor)
            ])
            attachmentInfo.set(item: item)
            let fileSize = MediaHelper.fileSizeToString(try! FileManager.default.attributesOfItem(atPath: localUrl.path)[.size] as? UInt64)
            let time = timestampView?.text ?? ""
            timestampView?.text = item.state.direction == .incoming ? "\(time) · \(fileSize)" : "\(fileSize) · \(time)"
        } else {
            documentController = nil;

            let attachmentInfo = (self.linkView as? AttachmentInfoView) ?? AttachmentInfoView(frame: .zero);
            self.linkView = attachmentInfo;
            NSLayoutConstraint.activate([
                customView.leadingAnchor.constraint(equalTo: attachmentInfo.leadingAnchor),
                customView.trailingAnchor.constraint(equalTo: attachmentInfo.trailingAnchor),
                customView.topAnchor.constraint(equalTo: attachmentInfo.topAnchor),
                customView.bottomAnchor.constraint(equalTo: attachmentInfo.bottomAnchor)
            ])
            attachmentInfo.set(item: item);

            switch item.appendix.state {
            case .new:
                let sizeLimit = Settings.fileDownloadSizeLimit.integer();
                if sizeLimit > 0 {
                    if let sessionObject = XmppService.instance.getClient(for: item.account)?.sessionObject, (RosterModule.getRosterStore(sessionObject).get(for: JID(item.jid))?.subscription ?? .none).isFrom || (DBChatStore.instance.getChat(for: item.account, with: item.jid) as? Room != nil) {
                        _ = DownloadManager.instance.download(item: item, maxSize: sizeLimit >= Int.max ? Int64.max : Int64(sizeLimit * 1024 * 1024));
                        attachmentInfo.progress(show: true);
                        return;
                    }
                }
                attachmentInfo.progress(show: DownloadManager.instance.downloadInProgress(for: item));
            default:
                attachmentInfo.progress(show: DownloadManager.instance.downloadInProgress(for: item));
            }
        }
    }
    
    @available(iOS 13.0, *)
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { suggestedActions -> UIMenu? in
            return self.prepareContextMenu();
        };
    }
    
    @available(iOS 13.0, *)
    func prepareContextMenu() -> UIMenu {
        guard let item = self.item else {
            return UIMenu(title: "");
        }
        
        if let localUrl = DownloadStore.instance.url(for: "\(item.id)") {
            let items = [
                UIAction(title: "Preview", image: UIImage(systemName: "eye.fill"), handler: { action in
                    print("preview called");
                    self.open(url: localUrl, preview: true);
                }),
                UIAction(title: "Copy", image: UIImage(systemName: "doc.on.doc"), handler: { action in
                    guard let text = self.item?.copyText(withTimestamp: Settings.CopyMessagesWithTimestamps.getBool(), withSender: false) else {
                        return;
                    }
                    UIPasteboard.general.strings = [text];
                    UIPasteboard.general.string = text;
                }),
                UIAction(title: "Share..", image: UIImage(systemName: "square.and.arrow.up"), handler: { action in
                    print("share called");
                    self.open(url: localUrl, preview: false);
                }),
                UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: [.destructive], handler: { action in
                    print("delete called");
                    DownloadStore.instance.deleteFile(for: "\(item.id)");
                    DBChatHistoryStore.instance.updateItem(for: item.account, with: item.jid, id: item.id, updateAppendix: { appendix in
                        appendix.state = .removed;
                    })
                }),
                UIAction(title: "More..", image: UIImage(systemName: "ellipsis"), handler: { action in
                    NotificationCenter.default.post(name: Notification.Name("tableViewCellShowEditToolbar"), object: self);
                })
            ];
            return UIMenu(title: "", image: nil, identifier: nil, options: [], children: items);
        } else {
            let items = [
                UIAction(title: "Copy", image: UIImage(systemName: "doc.on.doc"), handler: { action in
                    guard let text = self.item?.copyText(withTimestamp: Settings.CopyMessagesWithTimestamps.getBool(), withSender: false) else {
                        return;
                    }
                    UIPasteboard.general.strings = [text];
                    UIPasteboard.general.string = text;
                }),
                UIAction(title: "Download", image: UIImage(systemName: "square.and.arrow.down"), handler: { action in
                    print("download called");
                    self.download(for: item);
                }),
                UIAction(title: "More..", image: UIImage(systemName: "ellipsis"), handler: { action in
                    NotificationCenter.default.post(name: Notification.Name("tableViewCellShowEditToolbar"), object: self);
                })
            ];
            return UIMenu(title: "", image: nil, identifier: nil, options: [], children: items);
        }
    }
    
    @objc func longPressGestureDidFire(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .recognized else {
            return;
        }
        downloadOrOpen();
    }
    
    @objc func tapGestureDidFire(_ recognizer: UITapGestureRecognizer) {
        downloadOrOpen();
    }
    
    var documentController: UIDocumentInteractionController? {
        didSet {
            if let value = oldValue {
                for recognizer in value.gestureRecognizers {
                    self.removeGestureRecognizer(recognizer)
                }
            }
            if let value = documentController {
                value.delegate = self;
                for recognizer in value.gestureRecognizers {
                    self.addGestureRecognizer(recognizer)
                }
            }
            longPressGestureRecognizer?.isEnabled = documentController == nil;
        }
    }
    
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        let rootViewController = ((UIApplication.shared.delegate as? AppDelegate)?.window?.rootViewController)!;
        if let viewController = rootViewController.presentingViewController {
            return viewController;
        }
        return rootViewController;
    }
    
    func open(url: URL, preview: Bool) {
        print("opening a file:", url, "exists:", FileManager.default.fileExists(atPath: url.path));// "tmp:", tmpUrl);
        let documentController = UIDocumentInteractionController(url: url);
        documentController.delegate = self;
        print("detected uti:", documentController.uti as Any, "for:", documentController.url as Any);
        if preview && documentController.presentPreview(animated: true) {
            self.documentController = documentController;
        } else if documentController.presentOptionsMenu(from: self.superview?.convert(self.frame, to: self.superview?.superview) ?? CGRect.zero, in: self.self, animated: true) {
            self.documentController = documentController;
        }
    }
    
    func download(for item: ChatAttachment) {
        _ = DownloadManager.instance.download(item: item, maxSize: Int64.max);
        (self.linkView as? AttachmentInfoView)?.progress(show: true);
    }
    
    private func downloadOrOpen() {
        guard let item = self.item else {
            return;
        }
        if let localUrl = DownloadStore.instance.url(for: "\(item.id)") {
            open(url: localUrl, preview: true);
        } else {
            let alert = UIAlertController(title: "Download", message: "File is not available locally. Should it be downloaded?", preferredStyle: .alert);
            alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { (action) in
                self.download(for: item);
            }))
            alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil));
            if let controller = (UIApplication.shared.delegate as? AppDelegate)?.window?.rootViewController {
                controller.present(alert, animated: true, completion: nil);
            }
        }
    }
        
    class AttachmentInfoView: UIView {
        
        var imageWidthConstraint: NSLayoutConstraint?
        var imageHeightConstraint: NSLayoutConstraint?
        
        let iconView: ImageAttachmentPreview;
        let filename: UILabel;
        let details: UILabel;
        let playImage: UIImageView
        
        private var viewType: ViewType = .none {
            didSet {
                guard viewType != oldValue else {
                    return;
                }
                switch oldValue {
                case .none:
                    break;
                case .file:
                    NSLayoutConstraint.deactivate(fileViewConstraints);
                case .imagePreview, .videoPreview:
                    NSLayoutConstraint.deactivate(imagePreviewConstraints);
                }
                switch viewType {
                case .none:
                    break;
                case .file:
                    addSubview(filename)
                    addSubview(details)
                    self.imageWidthConstraint?.isActive = false
                    self.imageHeightConstraint?.isActive = false
                    NSLayoutConstraint.activate(fileViewConstraints);
                case .imagePreview:
                    filename.removeFromSuperview()
                    details.removeFromSuperview()
                    playImage.removeFromSuperview()
                    NSLayoutConstraint.activate(imagePreviewConstraints)
                case .videoPreview:
                    filename.removeFromSuperview()
                    details.removeFromSuperview()
                    NSLayoutConstraint.activate(imagePreviewConstraints)
                    addPlayImage()
                }
                iconView.contentMode = .scaleAspectFit
                iconView.isImagePreview = true
            }
        }
        
        private var fileViewConstraints: [NSLayoutConstraint] = [];
        private var imagePreviewConstraints: [NSLayoutConstraint] = [];
        
        override init(frame: CGRect) {
            iconView = ImageAttachmentPreview(frame: .zero)
            iconView.clipsToBounds = true
            iconView.translatesAutoresizingMaskIntoConstraints = false;

            filename = UILabel(frame: .zero);
            filename.font = UIFont.systemFont(ofSize: UIFont.systemFontSize - 1, weight: .semibold);
            filename.translatesAutoresizingMaskIntoConstraints = false;
            filename.setContentHuggingPriority(.defaultHigh, for: .horizontal);
            filename.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal);
            
            details = UILabel(frame: .zero);
            details.font = UIFont.systemFont(ofSize: UIFont.systemFontSize - 2, weight: .regular);
            details.translatesAutoresizingMaskIntoConstraints = false;
            details.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            details.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal);
            
            playImage = UIImageView()
            playImage.image = UIImage(named: "play.fill")
            playImage.translatesAutoresizingMaskIntoConstraints = false
            playImage.widthAnchor.constraint(equalToConstant: 30).isActive = true
            playImage.heightAnchor.constraint(equalToConstant: 30).isActive = true

            super.init(frame: frame);
            self.clipsToBounds = true
            self.translatesAutoresizingMaskIntoConstraints = false;
            self.isOpaque = false;
            
            addSubview(iconView);
            
            fileViewConstraints = [
                iconView.heightAnchor.constraint(equalToConstant: 30),
                iconView.widthAnchor.constraint(equalTo: iconView.heightAnchor),
                
                iconView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 12),
                iconView.topAnchor.constraint(equalTo: self.topAnchor, constant: 8),
                iconView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -8),
                
                filename.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
                filename.topAnchor.constraint(equalTo: self.topAnchor, constant: 8),
                filename.trailingAnchor.constraint(lessThanOrEqualTo: self.trailingAnchor, constant: -12),

                details.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
                details.topAnchor.constraint(equalTo: filename.bottomAnchor, constant: 0),
                details.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -8),
                // -- this is causing issue with progress indicatior!!
                details.trailingAnchor.constraint(lessThanOrEqualTo: self.trailingAnchor, constant: -12),
                details.heightAnchor.constraint(equalTo: filename.heightAnchor)
            ];
            
            imagePreviewConstraints = [
                iconView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
                iconView.topAnchor.constraint(equalTo: self.topAnchor),
                iconView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
                iconView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
                
            ];
            self.imageWidthConstraint = iconView.widthAnchor.constraint(equalToConstant: 0)
            self.imageHeightConstraint = iconView.heightAnchor.constraint(equalToConstant: 0)
        }
        
        func addPlayImage() {
            self.addSubview(playImage)
            playImage.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
            playImage.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        }
        
        func setImageConstraints(image: UIImage?) {
            guard let image = image else { return }
            if viewType == .file { return }
            
            var scale: CGFloat = 0.0
            var width = UIScreen.main.bounds.width
            var height = UIScreen.main.bounds.height
            width *= 0.7
            height *= 0.4
            if image.size.width > image.size.height {
                scale = width / image.size.width
            } else {
                scale = height / image.size.height
            }
            
            self.imageWidthConstraint?.constant = image.size.width * scale
            self.imageHeightConstraint?.constant = image.size.height * scale
            self.imageWidthConstraint?.isActive = true
            self.imageHeightConstraint?.isActive = true
        }
        
        required init?(coder: NSCoder) {
            return nil;
        }
        
        override func draw(_ rect: CGRect) {
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 5);
            path.addClip();
            if #available(iOS 13.0, *) {
                UIColor.secondarySystemBackground.setFill();
            } else {
                UIColor.lightGray.withAlphaComponent(0.5).setFill();
            }
            path.fill();

            super.draw(rect);
        }
        
        func set(item: ChatAttachment) {
            if let fileUrl = DownloadStore.instance.url(for: "\(item.id)") {
                filename.text = fileUrl.lastPathComponent;
                let fileSize = MediaHelper.fileSizeToString(try! FileManager.default.attributesOfItem(atPath: fileUrl.path)[.size] as? UInt64);
                if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileUrl.pathExtension as CFString, nil)?.takeRetainedValue(), let typeName = UTTypeCopyDescription(uti)?.takeRetainedValue() as String? {
                    details.text = "\(typeName) - \(fileSize)";
                    
                    if UTTypeConformsTo(uti, kUTTypeImage) {
                        iconView.image = UIImage(contentsOfFile: fileUrl.path)!
                        self.viewType = .imagePreview;
                        self.setImageConstraints(image: iconView.image)
                    } else if UTTypeConformsTo(uti, kUTTypeMovie) {
                        iconView.image = MediaHelper.generateThumbnail(url: fileUrl)
                        self.viewType = .videoPreview
                        self.setImageConstraints(image: iconView.image)
                    } else {
                        self.viewType = .file;
                        iconView.image = UIImage.icon(forFile: fileUrl, mimeType: item.appendix.mimetype);
                    }
                } else {
                    details.text = fileSize;
                    iconView.image = UIImage.icon(forFile: fileUrl, mimeType: item.appendix.mimetype);
                    self.viewType = .file;
                }
            } else {
                let filename = item.appendix.filename ?? URL(string: item.url)?.lastPathComponent ?? "";
                if filename.isEmpty {
                    self.filename.text =  "Unknown file";
                } else {
                    self.filename.text = filename;
                }
                if let size = item.appendix.filesize {
                    if let mimetype = item.appendix.mimetype, let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimetype as CFString, nil)?.takeRetainedValue(), let typeName = UTTypeCopyDescription(uti)?.takeRetainedValue() as String? {
                        let fileSize = size >= 0 ? MediaHelper.fileSizeToString(UInt64(size)) : "";
                        details.text = "\(typeName) - \(fileSize)";
                        iconView.image = UIImage.icon(forUTI: uti as String);
                    } else {
                        details.text = MediaHelper.fileSizeToString(UInt64(size));
                        iconView.image = UIImage.icon(forUTI: "public.content");
                    }
                } else {
                    details.text = "--";
                    iconView.image = UIImage.icon(forUTI: "public.content");
                }
                self.viewType = .file;
            }
        }
        
        var progressView: UIActivityIndicatorView?;
        
        func progress(show: Bool) {
            guard show != (progressView != nil) else {
                return;
            }
            
            if show {
                let view = UIActivityIndicatorView(style: .gray);
                view.translatesAutoresizingMaskIntoConstraints = false;
                self.addSubview(view);
                NSLayoutConstraint.activate([
                    view.leadingAnchor.constraint(greaterThanOrEqualTo: filename.trailingAnchor, constant: 8),
                    view.leadingAnchor.constraint(greaterThanOrEqualTo: details.trailingAnchor, constant: 8),
                    view.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -12),
                    view.bottomAnchor.constraint(equalTo: self.bottomAnchor),
                    view.topAnchor.constraint(lessThanOrEqualTo: self.topAnchor)
                ])
                self.progressView = view;
                view.startAnimating();
            } else if let view = progressView {
                view.stopAnimating();
                self.progressView = nil;
                view.removeFromSuperview();
            }
        }
        
        enum ViewType {
            case none
            case file
            case imagePreview
            case videoPreview
        }
        
    }
}

class ImageAttachmentPreview: UIImageView {
    
    var isImagePreview: Bool = false {
        didSet {
            if isImagePreview != oldValue {
                if isImagePreview {
                    self.layer.cornerRadius = 5
                    //self.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner];
                } else {
                    self.layer.cornerRadius = 0;
                    self.layer.maskedCorners = [];
                }
            }
        }
    }
    
    var contentClippingRect: CGRect {
        guard let image = image else { return bounds }
        guard contentMode == .scaleAspectFit else { return bounds }
        guard image.size.width > 0 && image.size.height > 0 else { return bounds }

        let scale: CGFloat
        if image.size.width > image.size.height {
            scale = bounds.width / image.size.width
        } else {
            scale = bounds.height / image.size.height
        }

        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let x = (bounds.width - size.width) / 2.0
        let y = (bounds.height - size.height) / 2.0

        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame);
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

extension FileManager {
    public func fileExtension(forUTI utiString: String) -> String? {
        guard
            let cfFileExtension = UTTypeCopyPreferredTagWithClass(utiString as CFString, kUTTagClassFilenameExtension)?.takeRetainedValue() else
        {
            return nil
        }

        return cfFileExtension as String
    }
}

extension UIImage {
    class func icon(forFile url: URL, mimeType: String?) -> UIImage? {
        let controller = UIDocumentInteractionController(url: url);
        if mimeType != nil, let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType! as CFString, nil)?.takeRetainedValue() as String? {
            controller.uti = uti;
        }
        if controller.icons.count == 0 {
            controller.uti = "public.data";
        }
        let icons = controller.icons;
        print("got:", icons.last as Any, "for:", url.absoluteString);
        return icons.last;
    }

    class func icon(forUTI utiString: String) -> UIImage? {
        let controller = UIDocumentInteractionController(url: URL(fileURLWithPath: "temp.file"));
        controller.uti = utiString;
        if controller.icons.count == 0 {
            controller.uti = "public.data";
        }
        let icons = controller.icons;
        print("got:", icons.last as Any, "for:", utiString);
        return icons.last;
    }
    
}
