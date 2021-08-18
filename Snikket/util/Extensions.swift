//
//  Extensions.swift
//  Snikket
//
//  Created by Khalid Khan on 8/17/21.
//  Copyright © 2021 Snikket. All rights reserved.
//

import Foundation

extension TimeInterval {

    private var seconds: String {
        let sec = Int(self) % 60
        return String(format: "%0.2d", sec)
    }

    private var minutes: String {
        let min = ((Int(self) / 60 ) % 60)
        return String(format: "%0.2d", min)
    }

    private var hours: String {
        let hour = Int(self) / 3600
        return String(format: "%0.2d", hour)
    }

    var stringTime: String {
        if (Int(self) / 3600) != 0 {
            return "\(hours):\(minutes):\(seconds)"
        } else if ((Int(self) / 60 ) % 60) != 0 {
            return "\(minutes):\(seconds)"
        } else {
            return "00:\(seconds)"
        }
    }
}
