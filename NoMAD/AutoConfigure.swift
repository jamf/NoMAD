//
//  AutoConfigure.swift
//  NoMAD
//
//  Created by Admin on 7/14/16.
//  Copyright © 2016 Trusource Labs. All rights reserved.
//

import Foundation

    // site information
    
    public func setDefaults() {
    
    // do we have an AutoConfigure setting?
        
    if let autoConfigure = defaults.stringForKey("AutoConfigure") {
        switch autoConfigure {
            case "TSL":
                defaults.setObject("trusourcelabs.com", forKey: "ADDomain")
                defaults.setObject("TRUSOURCELABS.COM", forKey: "KerberosRealm")
                defaults.setObject("jupiter.trusourcelabs.com", forKey: "InternalSite")
                defaults.setObject("192.168.32.43", forKey: "InternalSiteIP")
                defaults.setObject(3, forKey: "Verbose")
                defaults.setObject("", forKey: "userCommandHotKey1")
                defaults.setObject("", forKey: "userCommandName1")
                defaults.setObject("", forKey: "userCommandTask1")
                defaults.setObject(7200, forKey: "secondsToRenew")
                defaults.setObject(1, forKey: "RenewTickets")
                defaults.setObject("", forKey: "AutoConfigure")
           
            case "JODA":
                defaults.setObject("jodapro.com", forKey: "ADDomain")
                defaults.setObject("JODAPRO.COM", forKey: "KerberosRealm")
                defaults.setObject("in-or-out.jodapro.com", forKey: "InternalSite")
                defaults.setObject("1.1.1.1", forKey: "InternalSiteIP")
                defaults.setObject("2k12.jodapro.com", forKey: "x509CA")
                defaults.setObject("User Auth", forKey: "Template")
                defaults.setObject(3, forKey: "Verbose")
                defaults.setObject("", forKey: "userCommandHotKey1")
                defaults.setObject("", forKey: "userCommandName1")
                defaults.setObject("", forKey: "userCommandTask1")
                defaults.setObject(7200, forKey: "secondsToRenew")
                defaults.setObject(1, forKey: "RenewTickets")
                defaults.setObject("", forKey: "AutoConfigure")
            
            default:
                // see if we're on AD
                getADSettings()
                break
            }
        }
        
        if defaults.boolForKey("LoginItem") {
            //TODO: Test this to make sure it actually does what I think it will. This should return the value of the key if found, otherwise false.
                addToLoginItems()
        }
    }

private func getADSettings() {
    
    let myADConfig = cliTask("/usr/sbin/dsconfigad -show").componentsSeparatedByString("\n")
    
    if myADConfig.count > 0 {
        if myADConfig[0] != "" {
            for line in myADConfig {
                if line.containsString("Active Directory Domain") {
                    let myDomain = (line as NSString).substringFromIndex(35)
                    defaults.setObject(myDomain, forKey: "ADDomain")
                    defaults.setObject(myDomain.uppercaseString, forKey: "KerberosRealm")
                    defaults.setObject("", forKey: "InternalSite")
                    defaults.setObject("", forKey: "InternalSiteIP")
                    defaults.setObject(0, forKey: "Verbose")
                    defaults.setObject("", forKey: "userCommandHotKey1")
                    defaults.setObject("", forKey: "userCommandName1")
                    defaults.setObject("", forKey: "userCommandTask1")
                    defaults.setObject(7200, forKey: "secondsToRenew")
                    defaults.setObject(1, forKey: "RenewTickets")
                    break
                }
            }
        }
    }
    
}

private func addToLoginItems() {
    
    NSLog("Creating LaunchAgent.")
    
    // see if the folder exists
    
    let myFileManager = NSFileManager()
    let myLaunchAgentFolder = NSHomeDirectory().stringByAppendingString("/Library/LaunchAgents/")
    
    if ( myFileManager.fileExistsAtPath( myLaunchAgentFolder, isDirectory: nil)) {
        
    } else {
        do {
            NSLog("Creating LaunchAgent folder.")
        try myFileManager.createDirectoryAtPath(myLaunchAgentFolder, withIntermediateDirectories: true, attributes: nil)
        } catch {
            NSLog("Can't create LaunchAgent folder.")
    }
    }
    
    // find the current app path and create a launch agent
    
    let myBinaryPath = NSBundle.mainBundle().bundlePath.stringByAppendingString("/Contents/MacOS/NoMAD")
    let myLaunchAgentPath = NSHomeDirectory().stringByAppendingString("/Library/LaunchAgents/com.trusourcelabs.NoMAD.plist")
    
    // build the launch agent plist file
    
    let data = NSMutableDictionary()
    
    data.setObject(true, forKey: "KeepAlive")
    data.setObject("com.trusourcelabs.NoMAD", forKey: "Label")
    data.setObject(true, forKey: "RunAtLoad")
    data.setObject([ myBinaryPath ], forKey: "ProgramArguments")
    data.setObject(["Aqua"], forKey: "LimitLoadToSessionType")
    
    data.writeToFile( myLaunchAgentPath, atomically: true)
    
    // clear the flag
    
    defaults.setObject(false, forKey: "LoginItem")
    
    // in honor of @macmule
    /*
    NSTask.launchedTaskWithLaunchPath(
        "/usr/bin/osascript",
        arguments: [
            "-e",
            "tell application \"System Events\" to make login item at end with properties {path:\"" + myAppPath + "\", hidden:false, name:\"NoMad Password Monitor\"}"
        ]
    )
 */
}
