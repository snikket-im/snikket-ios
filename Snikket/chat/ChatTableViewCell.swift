//
// ChatTableViewCell.swift
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
import MapKit
import TigaseSwift

class ChatTableViewCell: BaseChatTableViewCell, UITextViewDelegate {

    @IBOutlet weak var messageWidthConstraint: NSLayoutConstraint!
    
    @IBOutlet var messageTextView: MessageTextView!
    
    var item: ChatMessage?
    
    lazy var mapView: MKMapView = {
        let view = MKMapView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = true
        view.layer.cornerRadius = 3
        view.isZoomEnabled = false
        view.isScrollEnabled = false
        view.isRotateEnabled = false
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(openMaps))
        view.addGestureRecognizer(tapGesture)
        return view
    }()
    
    fileprivate var originalTextColor: UIColor!;
    
    override var backgroundColor: UIColor? {
        didSet {
            if self.messageTextView != nil {
                self.messageTextView.backgroundColor = self.backgroundColor;
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        originalTextColor = messageTextView.textColor;
    }
    
    func set(message item: ChatMessage) {
        messageTextView.textView.delegate = self;
        super.set(item: item)
                
        mapView.removeFromSuperview()
        if isGeoLocation(message: item.message) {
            setupLocationCell(message: item.message)
            self.item = item
            return
        }
        
        let attrText = NSMutableAttributedString(string: item.message);
            
        if let detect = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue | NSTextCheckingResult.CheckingType.phoneNumber.rawValue) {
            let matches = detect.matches(in: item.message, options: .reportCompletion, range: NSMakeRange(0, item.message.count));
            for match in matches {
                var url: URL? = nil;
                if match.url != nil {
                    url = match.url;
                }
                if match.phoneNumber != nil {
                    url = URL(string: "tel:\(match.phoneNumber!.replacingOccurrences(of: " ", with: "-"))");
                }
                if let url = url {
                    attrText.setAttributes([.link : url], range: match.range);
                }
            }
        }
        let fgcolor = item.state.direction == .incoming ? "chatMessageText" : "chatMessageTextOutgoing";
        attrText.addAttribute(.foregroundColor, value: UIColor(named: fgcolor) as Any, range: NSRange(location: 0, length: attrText.length));
        
        if Settings.EnableMarkdownFormatting.getBool() {
            Markdown.applyStyling(attributedString: attrText, font: UIFont.systemFont(ofSize: self.messageTextView.fontSize + 2), showEmoticons:Settings.ShowEmoticons.getBool());
        } else if Settings.messageStyling.getBool() {
            MessageStyling.applyStyling(attributedString: attrText, font: .systemFont(ofSize: self.messageTextView.fontSize + 2), showEmoticons: Settings.ShowEmoticons.getBool())
        } else {
            attrText.addAttribute(.font, value: UIFont.systemFont(ofSize: self.messageTextView.fontSize + 2), range: NSRange(location: 0, length: attrText.length));
            attrText.fixAttributes(in: NSRange(location: 0, length: attrText.length));

        }
        self.messageTextView.attributedText = attrText;
        if item.state.isError {
            if (self.messageTextView.text?.isEmpty ?? true), let error = item.error {
                self.messageTextView.text = "Error: \(error)";
            }
            if item.state.direction == .incoming {
                self.messageTextView.textColor = UIColor.red;
            }
        } else {
            if item.encryption == .notForThisDevice || item.encryption == .decryptionFailed {
                self.messageTextView.textColor = self.originalTextColor;
            }
        }
        self.messageTextView.textView.textAlignment = .left
        
        var minWidth = (timestampView?.intrinsicContentSize.width ?? 52)
        if item.state.direction == .incoming { minWidth += (nicknameView?.intrinsicContentSize.width ?? 0) }
         
        if let lockImageHidden = lockStateImageView?.isHidden, !lockImageHidden {minWidth += 15 }
        let maxWidth = UIScreen.main.bounds.width * 0.60
        let userFont = UIFont.systemFont(ofSize: 14)
        var textWidth = (item.message).width(withConstrainedHeight: .greatestFiniteMagnitude, font: userFont)
        textWidth = textWidth > maxWidth ? maxWidth : textWidth
        textWidth = textWidth < minWidth ? minWidth : textWidth
        
        if let constraint = messageWidthConstraint {
            constraint.constant = textWidth + 20
        }
    }
    
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        UIApplication.shared.open(URL);
        return false;
    }
    
    @objc func openMaps() {
        guard let item = self.item else { return }
        let extractRegex = try! NSRegularExpression(pattern: "\\-?[0-9]+\\.?[0-9]*")
        let (lat,long) = matches(for: extractRegex, in: item.message)
        guard let lat = Double(lat), let long = Double(long) else { return }
        
        let regionDistance:CLLocationDistance = 1000
        let coordinates = CLLocationCoordinate2DMake(lat, long)
        let regionSpan = MKCoordinateRegion(center: coordinates, latitudinalMeters: regionDistance, longitudinalMeters: regionDistance)
        let options = [
            MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: regionSpan.center),
            MKLaunchOptionsMapSpanKey: NSValue(mkCoordinateSpan: regionSpan.span)
        ]
        let placemark = MKPlacemark(coordinate: coordinates, addressDictionary: nil)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = item.authorNickname ?? PEPDisplayNameModule.getDisplayName(account: item.account, for: item.jid)
        mapItem.openInMaps(launchOptions: options)
        
    }
    
    func isGeoLocation(message: String) -> Bool {
        let range = NSRange(location: 0, length: message.count)
        let regex = try! NSRegularExpression(pattern: "^geo:\\-?[0-9]+\\.?[0-9]*,\\-?[0-9]+\\.?[0-9]*$")
        
        if regex.firstMatch(in: message, options: [], range: range) != nil {
            
            return true
        } else {
            return false
        }
    }
    
    func matches(for regex: NSRegularExpression, in text: String) -> (String,String) {
        let results = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        let coordinates = results.map {
            String(text[Range($0.range, in: text)!])
        }
        if coordinates.count == 2 {
            return (coordinates[0], coordinates[1])
        } else { return("","") }
    }
    
    func setupLocationCell(message: String) {
        let extractRegex = try! NSRegularExpression(pattern: "\\-?[0-9]+\\.?[0-9]*")
        let (lat,long) = matches(for: extractRegex, in: message)
        guard let lat = Double(lat), let long = Double(long) else { return }
        
        self.messageTextView.addSubview(mapView)
        mapView.topAnchor.constraint(equalTo: messageTextView.topAnchor).isActive = true
        mapView.bottomAnchor.constraint(equalTo: messageTextView.bottomAnchor).isActive = true
        mapView.leadingAnchor.constraint(equalTo: messageTextView.leadingAnchor).isActive = true
        mapView.trailingAnchor.constraint(equalTo: messageTextView.trailingAnchor, constant: -5).isActive = true
        mapView.heightAnchor.constraint(equalToConstant: 200).isActive = true
        if let constraint = messageWidthConstraint {
            constraint.constant = UIScreen.main.bounds.width * 0.60
        }
        let location = CLLocation(latitude: lat, longitude: long)
        mapView.centerToLocation(location, animated: false)
        let annotation = MKPointAnnotation()
        annotation.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: long)
        mapView.addAnnotation(annotation)
    }
    
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromOptionalNSTextCheckingKeyDictionary(_ input: [NSTextCheckingKey: Any]?) -> [String: Any]? {
	guard let input = input else { return nil }
	return Dictionary(uniqueKeysWithValues: input.map {key, value in (key.rawValue, value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToOptionalNSAttributedStringKeyDictionary(_ input: [String: Any]?) -> [NSAttributedString.Key: Any]? {
	guard let input = input else { return nil }
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (NSAttributedString.Key(rawValue: key), value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromNSAttributedStringKey(_ input: NSAttributedString.Key) -> String {
	return input.rawValue
}

extension String {
    func width(withConstrainedHeight height: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: .greatestFiniteMagnitude, height: height)
        let boundingBox = self.boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, attributes: [.font: font], context: nil)
        
        return ceil(boundingBox.width)
    }
}
