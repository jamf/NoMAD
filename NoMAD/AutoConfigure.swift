//
//  AutoConfigure.swift
//  NoMAD
//
//  Created by Joel Rennich on 7/14/16.
//  Copyright © 2016 Trusource Labs. All rights reserved.
//

import Foundation
import SystemConfiguration

// site information

public func setDefaults() {

    // do we have an AutoConfigure setting?

    if let autoConfigure = defaults.string(forKey: Preferences.autoConfigure) {
        switch autoConfigure {
        case "TSL":
            defaults.set("trusourcelabs.com", forKey: Preferences.aDDomain)
            defaults.set("TRUSOURCELABS.COM", forKey: Preferences.kerberosRealm)
            defaults.set(true, forKey: Preferences.verbose)
            defaults.set("", forKey: Preferences.userCommandHotKey1)
            defaults.set("", forKey: Preferences.userCommandName1)
            defaults.set("", forKey: Preferences.userCommandTask1)
            defaults.set(7200, forKey: Preferences.secondsToRenew)
            defaults.set(1, forKey: Preferences.renewTickets)
            defaults.set("", forKey: Preferences.autoConfigure)

        case "JODA":
            defaults.set("jodapro.com", forKey: Preferences.aDDomain)
            defaults.set("JODAPRO.COM", forKey: Preferences.kerberosRealm)
            defaults.set("2k12.jodapro.com", forKey: Preferences.x509CA)
            defaults.set("User Auth", forKey: Preferences.template)
            defaults.set(true, forKey: Preferences.verbose)
            defaults.set("", forKey: Preferences.userCommandHotKey1)
            defaults.set("", forKey: Preferences.userCommandName1)
            defaults.set("", forKey: Preferences.userCommandTask1)
            defaults.set(7200, forKey: Preferences.secondsToRenew)
            defaults.set(1, forKey: Preferences.renewTickets)
            defaults.set("", forKey: Preferences.autoConfigure)

        default:
            // see if we're on AD
            getADSettings()
            break
        }
    }

    // if no defaults are set for ADDomain look to see if we're bound and use that

    if defaults.string(forKey: Preferences.aDDomain) == "" {
        myLogger.logit(.info, message: "No AD Domain set, determining if the machine is bound.")
        getADSettings()
    }

    if defaults.bool(forKey: Preferences.loginItem) {
        //TODO: Test this to make sure it actually does what I think it will. This should return the value of the key if found, otherwise false.
        addToLoginItems()
    }
}

private func getADSettings() {

    // TODO: do this programatically? Although may need to be root to see AD prefs

    let net_config = SCDynamicStoreCreate(nil, "net" as CFString, nil, nil)
    let ad_info = [ SCDynamicStoreCopyValue(net_config, "com.apple.opendirectoryd.ActiveDirectory" as CFString)]

    let adDict = ad_info[0]! as! NSDictionary

    if adDict.count > 1 {
            let myDomain = adDict["DomainNameDns"] as! String
                myLogger.logit(.base, message: "Setting AD Domain to the domain the machine is currently bound to.")
                defaults.set(myDomain, forKey: Preferences.aDDomain)
                defaults.set(myDomain.uppercased(), forKey: Preferences.kerberosRealm)
                defaults.set(false, forKey: Preferences.verbose)
                defaults.set("", forKey: Preferences.userCommandHotKey1)
                defaults.set("", forKey: Preferences.userCommandName1)
                defaults.set("", forKey: Preferences.userCommandTask1)
                defaults.set(7200, forKey: Preferences.secondsToRenew)
                defaults.set(1, forKey: Preferences.renewTickets)
    }
}

private func addToLoginItems() {

    NSLog("Creating LaunchAgent.")

    // see if the folder exists

    let myFileManager = FileManager()
    let myLaunchAgentFolder = NSHomeDirectory() + "/Library/LaunchAgents/"

    if ( myFileManager.fileExists( atPath: myLaunchAgentFolder, isDirectory: nil)) {

    }

    else {
        do {
            NSLog("Creating LaunchAgent folder.")

            try myFileManager.createDirectory(atPath: myLaunchAgentFolder, withIntermediateDirectories: true, attributes: nil)
        }

        catch {
            NSLog("Can't create LaunchAgent folder.")
            return
        }
    }

    // find the current app path and create a launch agent

    let myBinaryPath = Bundle.main.bundlePath + "/Contents/MacOS/NoMAD"
    let myLaunchAgentPath = NSHomeDirectory() + "/Library/LaunchAgents/com.trusourcelabs.NoMAD.plist"

    // build the launch agent plist file

    let data = NSMutableDictionary()

    data.setObject(true, forKey: "KeepAlive" as NSCopying)
    data.setObject("com.trusourcelabs.NoMAD", forKey: "Label" as NSCopying)
    data.setObject(true, forKey: "RunAtLoad" as NSCopying)
    data.setObject([ myBinaryPath ], forKey: "ProgramArguments" as NSCopying)
    data.setObject(["Aqua"], forKey: "LimitLoadToSessionType" as NSCopying)

    data.write( toFile: myLaunchAgentPath, atomically: true)

    // clear the flag

    defaults.set(false, forKey: Preferences.loginItem)

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
