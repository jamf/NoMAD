//
//  Welcome.swift
//  NoMAD
//
//  Created by Joel Rennich on 7/2/17.
//  Copyright © 2017 NoMAD. All rights reserved.
//

import Foundation
import Cocoa

let welcome = Welcome()

class Welcome: NSWindowController, NSWindowDelegate {
    
    @IBOutlet weak var versionField: NSTextField!
    
    @IBOutlet weak var setUpAccounts: NSButton!
    
    override var windowNibName: String? {
        return "Welcome"
    }
    
    override func windowDidLoad() {
        // set the version number
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let version = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        versionField.stringValue = "Version: " + shortVersion + " Build: " + version
    }
    
    func windowWillClose(_ notification: Notification) {
        defaults.set(true, forKey: Preferences.firstRunDone)
    }
    
    @IBAction func clickDone(_ sender: Any) {
        self.window?.close()
    }
    
}
