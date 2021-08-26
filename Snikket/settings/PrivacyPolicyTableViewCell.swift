//
//  PrivacyPolicyTableViewCell.swift
//  Snikket
//
//  Created by Khalid Khan on 8/26/21.
//  Copyright © 2021 Snikket. All rights reserved.
//

import UIKit

class PrivacyPolicyTableViewCell: UITableViewCell {

    @IBOutlet weak var policyTextView: UITextView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    func setupCell(domain: String) {
        let urlString = "terms and privacy policy"
        let textString = "By registering on this service you agree to abide by the terms and privacy policy"
        let urlRange = (textString as NSString).range(of: urlString)
        let attributedString = NSMutableAttributedString(string: textString)
        
        let url = URL(string: "https://\(domain)/policies/")!

        attributedString.setAttributes([.link: url], range: urlRange)

        self.policyTextView.attributedText = attributedString
        self.policyTextView.isUserInteractionEnabled = true
        self.policyTextView.isEditable = false

        self.policyTextView.linkTextAttributes = [
            .foregroundColor: UIColor.blue
        ]
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
