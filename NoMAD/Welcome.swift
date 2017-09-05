//
//  Welcome.swift
//  NoMAD
//
//  Created by Joel Rennich on 7/2/17.
//  Copyright © 2017 NoMAD. All rights reserved.
//

import Foundation
import Cocoa
import WebKit

let welcome = Welcome()

class Welcome: NSWindowController, NSWindowDelegate {
    
    @IBOutlet weak var welcomeWindow: NSView!
    
    @IBOutlet weak var versionField: NSTextField!
    @IBOutlet weak var displaySplash: WKWebView!
    
    override var windowNibName: String? {
        return "Welcome"
    }
    
    override func windowDidLoad() {
        // set the version number
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let version = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        versionField.stringValue = "Version: " + shortVersion + " Build: " + version
        
        // Setting the welcome splash screen
        do {
            myLogger.logit(.debug, message: "Attempting to load custom welcome splash screen.")
            var customSplashPath : URL
            if defaults.object(forKey: Preferences.menuWelcome) != nil {
                
                // Loading the users custom view
                var customSplashPref = "file://"
                customSplashPref += defaults.object(forKey: Preferences.menuWelcome) as! String
                myLogger.logit(.debug, message: "loading: " + customSplashPref)
                customSplashPath = URL.init(string: customSplashPref)!
            } else {
                
                // Using the default view
                customSplashPath = Bundle.main.url(forResource: "WelcomeSplash", withExtension: "html")!
            }
            
            // Displaying it out to the webview
            let customSplashFile = try String(contentsOf: customSplashPath, encoding: String.Encoding.utf8)
            displaySplash.loadHTMLString(customSplashFile, baseURL: customSplashPath)
            
        } catch {
            myLogger.logit(.debug, message: "Error reading contents of file")
            return
        }
    }
    
    func windowWillClose(_ notification: Notification) {
        defaults.set(true, forKey: Preferences.firstRunDone)
    }
    
    @IBAction func clickDone(_ sender: Any) {
        self.window?.close()
    }
    
}
