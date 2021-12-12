//
// ChatsListTableViewCell.swift
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

class ChatsListTableViewCell: UITableViewCell {

    // MARK: Properties
    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var avatarStatusView: AvatarStatusView! {
        didSet {
            if #available(iOS 13.0, *) {
                avatarStatusView?.backgroundColor = UIColor.systemBackground;
            } else {
                avatarStatusView?.backgroundColor = UIColor.white;
            }
        }
    }
    @IBOutlet var lastMessageLabel: UILabel!
    @IBOutlet var timestampLabel: UILabel!
    
    override var backgroundColor: UIColor? {
        get {
            return super.backgroundColor;
        }
        set {
            if #available(iOS 13.0, *) {
                super.backgroundColor = UIColor.systemBackground;
                avatarStatusView?.backgroundColor = UIColor.systemBackground;
            } else {
                super.backgroundColor = UIColor.white;
                avatarStatusView?.backgroundColor = UIColor.white;
            }
        }
    }    

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        avatarStatusView.statusImageView.isHidden = true
    }
}
