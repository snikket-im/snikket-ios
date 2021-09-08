//
//  Extensions.swift
//  Snikket
//
//  Created by Khalid Khan on 8/17/21.
//  Copyright © 2021 Snikket. All rights reserved.
//

import Foundation
import UIKit

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

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}

extension UIApplication {
    class func topViewController(controller: UIViewController? = UIApplication.shared.keyWindow?.rootViewController) -> UIViewController? {
        
        if let splitController = controller as? GlobalSplitViewController, let first = splitController.viewControllers.first {
            return topViewController(controller: first)
        }
        
        if let navigationController = controller as? UINavigationController {
            return topViewController(controller: navigationController.visibleViewController)
        }
        if let tabController = controller as? UITabBarController {
            if let selected = tabController.selectedViewController {
                return topViewController(controller: selected)
            }
        }
        if let presented = controller?.presentedViewController {
            return topViewController(controller: presented)
        }
        return controller
    }
}
