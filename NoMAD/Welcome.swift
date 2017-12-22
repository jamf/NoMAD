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
    
    @IBOutlet weak var webView: WebView!
    @IBOutlet weak var versionField: NSTextField!
    
    @objc override var windowNibName: NSNib.Name {
        return NSNib.Name(rawValue: "Welcome")
    }
    
    override func windowDidLoad() {
        // set the version number
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        versionField.stringValue = "Version: " + shortVersion
        
        welcomeWindow.window?.title = "Welcome to " + ((Bundle.main.bundlePath.components(separatedBy: "/").last?.replacingOccurrences(of: ".app", with: "")) ?? "NoMAD" )
        
        
        // Setting the welcome splash screen
        do {
            var customSplashPath : URL
            var customSplashDir : URL
            var customSplashFile : String
            
            if defaults.object(forKey: Preferences.menuWelcome) != nil {
                
                myLogger.logit(.debug, message: "Attempting to load custom welcome splash screen.")

                // Loading the users custom view
                
                // check for trailing / and add if necessary
                
                var customSplash = defaults.object(forKey: Preferences.menuWelcome) as! String
                
                if customSplash.last != "/" {
                    customSplash += "/"
                }
                
                myLogger.logit(.debug, message: "loading: " + customSplash)
                
                customSplashPath =  URL.init(string: customSplash + "index.html")!
                customSplashDir = URL.init(string: customSplash)!
                
                customSplashFile = try String.init(contentsOfFile: customSplashPath.absoluteString)
                
            } else {
                
                // Using the default view
                customSplashPath = Bundle.main.url(forResource: "WelcomeSplash", withExtension: "html")!
                customSplashDir = customSplashPath
                customSplashFile = try String(contentsOf: customSplashPath, encoding: String.Encoding.utf8)
            }
            
            // Displaying it out to the webview

            myLogger.logit(.debug, message: "Using Default display method due to older OSX version.")
            //let customSplashFile = try String(contentsOf: customSplashPath, encoding: String.Encoding.utf8)
            
            webView.mainFrame.loadHTMLString(customSplashFile, baseURL: customSplashDir)
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
