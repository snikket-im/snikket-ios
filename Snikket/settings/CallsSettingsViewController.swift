//
//  CallsSettingsViewController.swift
//  Snikket
//
//  Created by Muhammad Khalid on 29/10/2021.
//  Copyright © 2021 Snikket. All rights reserved.
//

import UIKit
import CallKit

class CallsSettingsViewController: UITableViewController {
    
    @IBOutlet weak var callsSwitch: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        callsSwitch.isOn = Settings.addCallsToSystem.getBool()
    }

    // MARK: - Table view data source
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    @IBAction func valueChanged(_ sender: UISwitch) {
        Settings.addCallsToSystem.setValue(sender.isOn)
        enableAddCallsToSystem(enable: sender.isOn)
    }
    
    func enableAddCallsToSystem(enable: Bool) {
        let config = CXProviderConfiguration(localizedName: "Snikket");
        if #available(iOS 13.0, *) {
            if let image = UIImage(systemName: "message.fill") {
                config.iconTemplateImageData = image.pngData();
            }
        } else {
            if let image = UIImage(named: "message.fill") {
                config.iconTemplateImageData = image.pngData();
            }
        }
        config.includesCallsInRecents = enable;
        config.supportsVideo = true;
        config.maximumCallsPerCallGroup = 1;
        config.maximumCallGroups = 1;
        config.supportedHandleTypes = [.generic];

        CallManager.instance?.provider = CXProvider(configuration: config);
        CallManager.instance?.provider.setDelegate(CallManager.instance, queue: nil)
    }
}
