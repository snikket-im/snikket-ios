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
import CommonCrypto

class AvatarColors {
    
    static let colors = [
                    "0xFFE91E63", //pink 500
                    "0xFFD81B60", //pink 600
                    "0xFFC2185B", //pink 700
                    "0xFFAD1457", //pink 800

                    "0xFF9C27B0", //purple 500
                    "0xFF8E24AA", //purple 600
                    "0xFF7B1FA2", //purple 700
                    "0xFF6A1B9A", //purple 800

                    "0xFF673AB7", //deep purple 500,
                    "0xFF5E35B1", //deep purple 600
                    "0xFF512DA8", //deep purple 700
                    "0xFF4527A0", //deep purple 800,

                    "0xFF3F51B5", //indigo 500,
                    "0xFF3949AB",//indigo 600
                    "0xFF303F9F",//indigo 700
                    "0xFF283593", //indigo 800

                    "0xFF2196F3", //blue 500
                    "0xFF1E88E5", //blue 600
                    "0xFF1976D2", //blue 700
                    "0xFF1565C0", //blue 800

                    "0xFF03A9F4", //light blue 500
                    "0xFF039BE5", //light blue 600
                    "0xFF0288D1", //light blue 700
                    "0xFF0277BD", //light blue 800

                    "0xFF00BCD4", //cyan 500
                    "0xFF00ACC1", //cyan 600
                    "0xFF0097A7", //cyan 700
                    "0xFF00838F", //cyan 800

                    "0xFF009688", //teal 500,
                    "0xFF00897B", //teal 600
                    "0xFF00796B", //teal 700
                    "0xFF00695C", //teal 800,

                    "0xFF9E9D24", //lime 800

                    "0xFF795548", //brown 500,
        
                    "0xFF607D8B", //blue grey 500,
        
                    // Unsafe Colors
        
                    "0xFFF44336", //red 500
                    "0xFFE53935", //red 600
                    "0xFFD32F2F", //red 700
                    "0xFFC62828", //red 800

                    "0xFFEF6C00", //orange 800

                    "0xFFF4511E", //deep orange 600
                    "0xFFE64A19", //deep orange 700
                    "0xFFD84315" //deep orange 800,
    ]
    
    static func getColorForName(name: String) -> UIColor {
            
        if name == "" {
            return UIColor(hex: "0xFF202020") ?? .gray
        }
        let index = (getValueForName(name))
        guard index < colors.count else { return .gray }
        let colorHex = colors[Int(index)]
        return UIColor(hex: colorHex) ?? .gray
    }
    
    private static func getValueForName(_ name: String) -> Int64 {
        guard let data: Data = Digest.md5.digest(data: name.data(using: .utf8)) else { return 0 }
        
        //let signed = data.map { Int8(bitPattern: $0) }
        
        if var value = data.to(type: Int64.self) {
            value = abs(value)
            let modulo = value % Int64(colors.count)
            return modulo
        }
        return 0
    }
}




