//
//  DisplayNameViewController.swift
//  Snikket
//
//  Created by Khalid Khan on 8/23/21.
//  Copyright © 2021 Snikket. All rights reserved.
//

import UIKit
import TigaseSwift

class DisplayNameViewController: UIViewController {

    @IBOutlet weak var textView: UITextView!
    
    var account : BareJID?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupField()
        setupNavigationBar()
    }

    func setupField() {
        textView.clipsToBounds = true
        textView.layer.cornerRadius = 5
        textView.layer.borderColor = UIColor.darkGray.cgColor
        textView.layer.borderWidth = 1
        
        if let account = account, let displayName = AccountSettings.displayName(account).getString() {
            textView.text = displayName
            textView.textColor = .black
        } else {
            textView.text = "Name"
            textView.textColor = .lightGray
        }
        
    }
    
    func setupNavigationBar() {
        self.title = "Your Name"
        
        let righButton  = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
        self.navigationItem.rightBarButtonItem = righButton
    }
    
    @objc func done() {
        if !textView.text.isEmpty, let account = account {
            AccountSettings.displayName(account).set(string: textView.text)
        }
        self.navigationController?.popViewController(animated: true)
    }
    
}

extension DisplayNameViewController: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.textColor == UIColor.lightGray {
            textView.text = nil
            textView.textColor = UIColor.black
        }
    }
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.isEmpty {
            textView.text = "Name"
            textView.textColor = UIColor.lightGray
        }
    }
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n", !textView.text.isEmpty, let account = account {
            AccountSettings.displayName(account).set(string: textView.text)
            self.navigationController?.popViewController(animated: true)
            textView.resignFirstResponder()
            return false
        }
        else if text == "\n" {
            self.navigationController?.popViewController(animated: true)
            textView.resignFirstResponder()
        }
        return true
    }
}