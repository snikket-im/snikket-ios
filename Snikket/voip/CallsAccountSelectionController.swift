//
//  CallsAccountSelectionController.swift
//  Snikket
//
//  Created by Muhammad Khalid on 02/11/2021.
//  Copyright © 2021 Snikket. All rights reserved.
//

import UIKit
import TigaseSwift

class CallsAccountSelectionController: UITableViewController {

    var didSelectAccount: ((BareJID) -> Void)!
    
    var accounts = [BareJID]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { accounts.count }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = self.accounts[indexPath.row].stringValue
        cell.textLabel?.textAlignment = .center
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        self.dismiss(animated: true, completion: {
            self.didSelectAccount(self.accounts[indexPath.row])
        })
    }
}
