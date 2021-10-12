//
//  TelephonyProviderViewController.swift
//  Snikket
//
//  Created by Muhammad Khalid on 08/10/2021.
//  Copyright © 2021 Snikket. All rights reserved.
//

import UIKit
import TigaseSwift

class TelephonyProviderViewController: UITableViewController {

    var account: BareJID!
    var selected = "None"
    var providers: [JID] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loadProviders()
        selected = AccountSettings.telephonyProvider(account).getString() ?? "None"
    }
    
    func loadProviders() {
        let client = XmppService.instance.getClient(for: account)
        let rosterModule: RosterModule? = client?.modulesManager.getModule(RosterModule.ID)
        if let module = rosterModule {
            let contacts = module.rosterStore.getJids()
            
            for contact in contacts {
                if contact.localPart == nil {
                    verifyService(client: client, jid: contact)
                }
                
            }
        }
    }
    
    func verifyService(client: XMPPClient?, jid: JID) {
        if let module: DiscoveryModule = client?.modulesManager.getModule(DiscoveryModule.ID) {
            module.getInfo(for: jid, node: nil, completionHandler: { result in
                switch result {
                case .success(_, let identities, _):
                    for identity in identities {
                        if identity.category.lowercased() == "gateway", identity.type.lowercased() == "pstn" {
                            self.providers.append(jid)
                            DispatchQueue.main.async {
                                self.tableView.reloadData()
                            }
                        }
                    }
                case .failure(let errorCondition, _):
                    print(errorCondition)
                }
            })
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.providers.count + 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if indexPath.row == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "TelephonyProviderCell", for: indexPath)
            cell.textLabel?.text = "None"
            cell.accessoryType = "None" == selected ? .checkmark : .none
            return cell
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "TelephonyProviderCell", for: indexPath)
        let feature = providers[indexPath.row - 1]
        cell.textLabel?.text = feature.stringValue
        cell.accessoryType = feature.stringValue == selected ? .checkmark : .none;
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 0 {
            AccountSettings.telephonyProvider(self.account).set(string: nil)
            selected = "None"
        } else {
            let provider = providers[indexPath.row - 1]
            AccountSettings.telephonyProvider(self.account).set(string: provider.stringValue)
            selected = provider.stringValue
        }
        tableView.reloadData()
        
    }

}
