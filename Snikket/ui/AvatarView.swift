//
// AvatarStatusView.swift
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

class AvatarView: UIImageView {
    
    private var name: String? {
        didSet {
            if let parts = name?.uppercased().components(separatedBy: CharacterSet.letters.inverted) {
                let first = parts.first?.first;
                let last = parts.count > 1 ? parts.last?.first : nil;
                self.initials = (last == nil || first == nil) ? (first == nil ? nil : "\(first!)") : "\(first!)\(last!)";
            } else {
                self.initials = nil;
            }
            self.setNeedsDisplay();
        }
    }
    
    override var frame: CGRect {
        didSet {
            self.layer.cornerRadius = 2;
        }
    }

    fileprivate(set) var initials: String?;
    
    func set(bareJID: BareJID? = nil, name: String?, avatar: UIImage?, orDefault defAvatar: UIImage, backColor: UIColor = UIColor.systemGray) {
        self.name = name;
        if avatar != nil {
            self.image = avatar;
        } else if self.name != nil {
            if self.name != name {
                self.name = name;
            }
            if let initials = self.initials {
                self.image = self.prepareInitialsAvatar(for: initials, backColor: AvatarColors.getColorForName(name: bareJID?.stringValue ?? (name ?? "")));
            } else {
                 self.image = defAvatar;
            }
        } else {
             self.image = defAvatar;
        }
    }
    
    func setGroup(bareJIDS: [BareJID], memberNames: [String], memberImages: [UIImage], avatar: UIImage?, defAvatar: UIImage, backColor: UIColor = .systemGray) {
        self.image = nil
        if avatar != nil {
            self.image = avatar
        }
        else if !memberNames.isEmpty {
            let memberInitials = memberNames.map { return self.getInitials(name: $0) }
            if memberInitials.count == 1 {
                let memberColor = AvatarColors.getColorForName(name: bareJIDS[0].stringValue)
                self.image = self.prepareInitialsAvatar(for: memberInitials.first!, backColor: memberColor)
            } else if memberInitials.count == 2 {
                //2
                let image1 = memberImages.isEmpty ? nil : memberImages[0]
                let image2 = memberImages.count > 1 ? memberImages[1] : nil
                
                let member1Color = AvatarColors.getColorForName(name: bareJIDS[0].stringValue)
                let member2Color = AvatarColors.getColorForName(name: bareJIDS[1].stringValue)
                
                self.image = groupImagefor2(member1: memberInitials[0], member2: memberInitials[1], member1Image: image1, member2Image: image2, member1Color: member1Color, member2Color: member2Color)
            } else if memberInitials.count == 3 {
                //3
                let image1 = memberImages.isEmpty ? nil : memberImages[0]
                let image2 = memberImages.count > 1 ? memberImages[1] : nil
                let image3 = memberImages.count > 2 ? memberImages[2] : nil
                
                let member1Color = AvatarColors.getColorForName(name: bareJIDS[0].stringValue)
                let member2Color = AvatarColors.getColorForName(name: bareJIDS[1].stringValue)
                let member3Color = AvatarColors.getColorForName(name: bareJIDS[2].stringValue)
                
                self.image = groupImagefor3(member1: memberInitials[0], member2: memberInitials[1], member3: memberInitials[2], member1Image: image1, member2Image: image2, member3Image: image3, member1Color: member1Color, member2Color: member2Color, member3Color: member3Color)
            } else {
                //4
                let image1 = memberImages.isEmpty ? nil : memberImages[0]
                let image2 = memberImages.count > 1 ? memberImages[1] : nil
                let image3 = memberImages.count > 2 ? memberImages[2] : nil
                
                let member1Color = AvatarColors.getColorForName(name: bareJIDS[0].stringValue)
                let member2Color = AvatarColors.getColorForName(name: bareJIDS[1].stringValue)
                let member3Color = AvatarColors.getColorForName(name: bareJIDS[2].stringValue)
                
                self.image = groupImagefor4(member1: memberInitials[0], member2: memberInitials[1], member3: memberInitials[2], member1Image: image1, member2Image: image2, member3Image: image3, member1Color: member1Color, member2Color: member2Color, member3Color: member3Color)
            }
        }
        else {
            self.image =  defAvatar
        }
        
    }
    
    func groupImagefor2(member1: String, member2: String, member1Image: UIImage?, member2Image: UIImage?, member1Color: UIColor, member2Color: UIColor) -> UIImage {
        let (size,scale) = sizeAndScale()
        let member1Image = resizeImage(image: member1Image, newWidth: size.width)
        let member2Image = resizeImage(image: member2Image, newWidth: size.width)
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        let ctx = UIGraphicsGetCurrentContext()!
        
        //Drawing in 1st half image or member letters
        if let image = member1Image {
            let targetRect = CGRect(x: 0, y: 0, width: (size.width / 2) - 2, height: size.height)
            let centerRect = CGRect(x: (size.width / 4), y: 0, width: (size.width / 2) - 2, height: size.height)
            let croppedImage = image.crop(rect: centerRect)
            croppedImage.draw(in: targetRect)
        }
        else {
            ctx.setFillColor(member1Color.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: (size.width / 2) - 2, height: size.height))
            let member1textAttr: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.white.withAlphaComponent(0.9), .font: UIFont.systemFont(ofSize: size.width * 0.4, weight: .medium)]
            let member1textSize = member1.size(withAttributes: member1textAttr)
            member1.draw(in: CGRect(x: size.width/4 - member1textSize.width/2, y: size.height/2 - member1textSize.height/2, width: member1textSize.width, height: member1textSize.height), withAttributes: member1textAttr)
        }
        
        //Drawing in 2nd half image or member letter
        if let image = member2Image {
            let targetRect = CGRect(x: (size.width / 2)+2, y: 0, width: (size.width / 2) - 2, height: size.height)
            let centerRect = CGRect(x: (size.width / 4), y: 0, width: (size.width / 2) - 2, height: size.height)
            let croppedImage = image.crop(rect: centerRect)
            croppedImage.draw(in: targetRect)
        }
        else {
            ctx.setFillColor(member2Color.cgColor)
            ctx.fill(CGRect(x: (size.width / 2)+2, y: 0, width: size.width, height: size.height))
            let member2textAttr: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.white.withAlphaComponent(0.9), .font: UIFont.systemFont(ofSize: size.width * 0.4, weight: .medium)]
            let member2textSize = member2.size(withAttributes: member2textAttr)
            member2.draw(in: CGRect(x: (size.width/4 + size.width/2) - member2textSize.width/2, y: size.height/2 - member2textSize.height/2, width: member2textSize.width, height: member2textSize.height), withAttributes: member2textAttr)
        }
        
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return image
    }
    
    func groupImagefor3(member1: String, member2: String, member3: String, member1Image: UIImage?, member2Image: UIImage?, member3Image: UIImage?, member1Color: UIColor, member2Color: UIColor, member3Color: UIColor) -> UIImage {
        let (size,scale) = sizeAndScale()
        let member1Image = resizeImage(image: member1Image, newWidth: size.width)
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        let ctx = UIGraphicsGetCurrentContext()!
        
        //Left
        if let image = member1Image {
            let targetRect = CGRect(x: 0, y: 0, width: (size.width / 2) - 2, height: size.height)
            let centerRect = CGRect(x: (size.width / 4), y: 0, width: (size.width / 2) - 2, height: size.height)
            let croppedImage = image.crop(rect: centerRect)
            croppedImage.draw(in: targetRect)
        } else {
            ctx.setFillColor(member1Color.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: (size.width / 2) - 2, height: (size.height / 2) - 2))
            let member1textAttr: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.white.withAlphaComponent(0.9), .font: UIFont.systemFont(ofSize: fontSize(text: member1, size: size), weight: .medium)]
            let member1textSize = member1.size(withAttributes: member1textAttr)
            member1.draw(in: CGRect(x: size.width/4 - member1textSize.width/2,
                                    y: size.height/4 - member1textSize.height/2,
                                    width: member1textSize.width,
                                    height: member1textSize.height), withAttributes: member1textAttr)
        }
        
        //Top Right
        if let image = member2Image {
            image.draw(in: CGRect(x: (size.width / 2)+2, y: 0, width: (size.width / 2) - 2, height: (size.height / 2) - 2))
        } else {
            ctx.setFillColor(member2Color.cgColor)
            ctx.fill(CGRect(x: (size.width / 2)+2, y: 0, width: size.width, height: (size.height / 2) - 2))
            let member2textAttr: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.white.withAlphaComponent(0.9), .font: UIFont.systemFont(ofSize: fontSize(text: member2, size: size), weight: .medium)]
            let member2textSize = member2.size(withAttributes: member2textAttr)
            member2.draw(in: CGRect(x: (size.width/4 + size.width/2) - member2textSize.width/2,
                                    y: size.height/4 - member2textSize.height/2,
                                    width: member2textSize.width,
                                    height: member2textSize.height), withAttributes: member2textAttr)
        }
        
        //Bottom Right
        if let image = member3Image {
            image.draw(in: CGRect(x: (size.width/2)+2, y: (size.height/2)+2, width: (size.width/2)-2, height: (size.height/2)-2))
        } else {
            ctx.setFillColor(member3Color.cgColor)
            ctx.fill(CGRect(x: (size.width/2)+2, y: (size.height/2)+2, width: (size.width/2)-2, height: (size.height/2)-2))
            let member3textAttr: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.white.withAlphaComponent(0.9), .font: UIFont.systemFont(ofSize: fontSize(text: member3, size: size), weight: .medium)]
            let member3textSize = member3.size(withAttributes: member3textAttr)
            member3.draw(in: CGRect(x: (size.width/4 + size.width/2) - member3textSize.width/2 ,
                                    y: (size.height/4 + size.height/2) - member3textSize.height/2,
                                    width: member3textSize.width,
                                    height: member3textSize.height), withAttributes: member3textAttr)
        }
        
        
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }
    
    func groupImagefor4(member1: String, member2: String, member3: String, member1Image: UIImage?, member2Image: UIImage?, member3Image: UIImage?, member1Color: UIColor, member2Color: UIColor, member3Color: UIColor) -> UIImage {
        let (size,scale) = sizeAndScale()
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        let ctx = UIGraphicsGetCurrentContext()!
        
        //Top Left
        if let image = member1Image {
            image.draw(in: CGRect(x: 0, y: 0, width: (size.width / 2) - 2, height: (size.height / 2) - 2))
        } else {
            ctx.setFillColor(member1Color.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: (size.width / 2) - 2, height: (size.height / 2) - 2))
            let member1textAttr: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.white.withAlphaComponent(0.9), .font: UIFont.systemFont(ofSize: fontSize(text: member1, size: size), weight: .medium)]
            let member1textSize = member1.size(withAttributes: member1textAttr)
            member1.draw(in: CGRect(x: size.width/4 - member1textSize.width/2, y: size.height/4 - member1textSize.height/2, width: member1textSize.width, height: member1textSize.height), withAttributes: member1textAttr)
        }
        
        //Top Right
        if let image = member2Image {
            image.draw(in: CGRect(x: (size.width / 2)+2, y: 0, width: (size.width / 2) - 2, height: (size.height / 2) - 2))
        } else {
            ctx.setFillColor(member2Color.cgColor)
            ctx.fill(CGRect(x: (size.width / 2)+2, y: 0, width: size.width, height: (size.height / 2) - 2))
            let member2textAttr: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.white.withAlphaComponent(0.9), .font: UIFont.systemFont(ofSize: fontSize(text: member2, size: size), weight: .medium)]
            let member2textSize = member2.size(withAttributes: member2textAttr)
            member2.draw(in: CGRect(x: (size.width/4 + size.width/2) - member2textSize.width/2,
                                    y: size.height/4 - member2textSize.height/2,
                                    width: member2textSize.width,
                                    height: member2textSize.height),
                                    withAttributes: member2textAttr)
        }
        
        //Bottom Left
        if let image = member3Image {
            image.draw(in: CGRect(x: 0, y: (size.height / 2) + 2, width: (size.width / 2) - 2, height: (size.height / 2) - 2))
        } else {
            ctx.setFillColor(member3Color.cgColor)
            ctx.fill(CGRect(x: 0, y: (size.height / 2) + 2, width: (size.width / 2) - 2, height: (size.height / 2) - 2))
            let member3textAttr: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.white.withAlphaComponent(0.9), .font: UIFont.systemFont(ofSize: fontSize(text: member3, size: size), weight: .medium)]
            let member3textSize = member3.size(withAttributes: member3textAttr)
            
            member3.draw(in: CGRect(x: size.width/4 - member3textSize.width/2,
                                    y: (size.height/4 + size.height/2) - member3textSize.height/2,
                                    width: member3textSize.width,
                                    height: member3textSize.height), withAttributes: member3textAttr)
        }
        
        //Bottom Right
        if let image = UIImage(named: "moreImg") {
            image.draw(in: CGRect(x: (size.width/2)+2, y: (size.height/2)+2, width: (size.width/2)-2, height: (size.height/2)-2))
        }
        
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return image
    }
    
    func sizeAndScale() -> (CGSize,CGFloat) {
        let scale = UIScreen.main.scale;
        var size = self.bounds.size;
        if self.contentMode == .redraw || contentMode == .scaleAspectFill || contentMode == .scaleAspectFit || contentMode == .scaleToFill {
            size.width = (size.width * scale)
            size.height = (size.height * scale)
        }
        return (size,scale)
    }
    
    func fontSize(text: String, size: CGSize) -> CGFloat {
        if text.count > 1 {
            return size.width * 0.3
        } else {
            return size.width * 0.4
        }
    }
    
    //Render for single user
    func prepareInitialsAvatar(for text: String, backColor: UIColor) -> UIImage {
        let (size,scale) = sizeAndScale()
        
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        let ctx = UIGraphicsGetCurrentContext()!
        
        ctx.setFillColor(backColor.cgColor);
        ctx.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        
        let textAttr: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.white.withAlphaComponent(0.9), .font: UIFont.systemFont(ofSize: size.width * 0.6, weight: .medium)]
        let textSize = text.size(withAttributes: textAttr)
        
        text.draw(in: CGRect(x: size.width/2 - textSize.width/2, y: size.height/2 - textSize.height/2, width: textSize.width, height: textSize.height), withAttributes: textAttr)
        
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return image
    }
    
    func getInitials(name: String) -> String {
        var initials:String?
        if name != "" {
            let parts = name.uppercased().components(separatedBy: CharacterSet.letters.inverted)
            let first = parts.first?.first;
            let last = parts.count > 1 ? parts.last?.first : nil;
            initials = (last == nil || first == nil) ? (first == nil ? nil : "\(first!)") : "\(first!)\(last!)";
        } else {
            initials = nil;
        }
        return initials ?? "?"
    }
    
    func resizeImage(image: UIImage?, newWidth: CGFloat) -> UIImage? {

        guard let image = image else { return nil }
        let scale = newWidth / image.size.width
        let newHeight = image.size.height * scale
        UIGraphicsBeginImageContext(CGSize(width: newWidth, height: newHeight))
        image.draw(in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))

        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage
    }
}

extension UIImage {
    func crop(rect: CGRect) -> UIImage {
        guard let cgImage = self.cgImage?.cropping(to: rect) else {
            return UIImage(named: "moreImg")!
        }
        return UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: .up)
    }
}
