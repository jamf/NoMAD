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
    
    @IBOutlet weak var onIcon: NSImageView!
    @IBOutlet weak var offIcon: NSImageView!
    
    override var windowNibName: String? {
        return "Welcome"
    }
    
    override func windowDidLoad() {
        // set the version number
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let version = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        versionField.stringValue = "Version: " + shortVersion + " Build: " + version
        
        if defaults.string(forKey: Preferences.iconOn) != nil {
            onIcon.image = NSImage.init(contentsOfFile: defaults.string(forKey: Preferences.iconOn)!)!
        }
        
        if defaults.string(forKey: Preferences.iconOff) != nil {
            offIcon.image = NSImage.init(contentsOfFile: defaults.string(forKey: Preferences.iconOff)!)!
        }
    }
    
    func windowWillClose(_ notification: Notification) {
        defaults.set(true, forKey: Preferences.firstRunDone)
    }
    
    @IBAction func clickDone(_ sender: Any) {
        self.window?.close()
    }
    
}
