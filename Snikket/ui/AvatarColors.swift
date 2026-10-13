//
//  AvatarColors.swift
//  Snikket
//
//  Created by Hammad Ashraf on 09/09/2021.
//  Copyright © 2021 Snikket. All rights reserved.
//

import Foundation
import UIKit
import TigaseSwift
import HSLuv

class AvatarColors {
    
    static func getColorForName(name: String) -> UIColor {
            
        if name == "" {
            return UIColor(hex: "0xFF202020") ?? .gray
        }
        
        return XEP0392Helper.rgbFromNick(name: name)
    }
}

class XEP0392Helper {
    
    private static func angle(_ name: String) -> Double {
        guard let data: Data = Digest.sha1.digest(data: name.data(using: .utf8)) else { return 0.0 }
        
        if data.count >= 2 {
            let angle = Int(data[0] & 0xFF) + Int(data[1] & 0xFF) * 256
            let value = Double(angle) / 65536.0
            return value
        }
        return 0.0
    }
    
    static func rgbFromNick(name: String) -> UIColor {
        let rgb = hsluvToRgb(angle(name) * 360, 100, 50)
        return UIColor(red: CGFloat(rgb.red), green: CGFloat(rgb.green), blue: CGFloat(rgb.blue), alpha: 1.0)
    }
}



