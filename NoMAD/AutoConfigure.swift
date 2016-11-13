//
//  AutoConfigure.swift
//  NoMAD
//
//  Created by Joel Rennich on 7/14/16.
//  Copyright © 2016 Trusource Labs. All rights reserved.
//

import Foundation

// site information

public func setDefaults() {

    // do we have an AutoConfigure setting?

    if let autoConfigure = defaults.string(forKey: Preferences.autoConfigure) {
        switch autoConfigure {
        case "TSL":
            defaults.set("trusourcelabs.com", forKey: Preferences.aDDomain)
            defaults.set("TRUSOURCELABS.COM", forKey: Preferences.kerberosRealm)
            //defaults.setObject("jupiter.trusourcelabs.com", forKey: "InternalSite")
            //defaults.setObject("192.168.32.43", forKey: "InternalSiteIP")
            defaults.set(true, forKey: Preferences.verbose)
            defaults.set("", forKey: Preferences.userCommandHotKey1)
            defaults.set("", forKey: Preferences.userCommandName1)
            defaults.set("", forKey: Preferences.userCommandTask1)
            defaults.set(7200, forKey: Preferences.secondsToRenew)
            defaults.set(1, forKey: "RenewTickets")
            defaults.set("", forKey: Preferences.autoConfigure)

        case "JODA":
            defaults.set("jodapro.com", forKey: Preferences.aDDomain)
            defaults.set("JODAPRO.COM", forKey: Preferences.kerberosRealm)
            //defaults.setObject("in-or-out.jodapro.com", forKey: "InternalSite")
            //defaults.setObject("1.1.1.1", forKey: "InternalSiteIP")
            defaults.set("2k12.jodapro.com", forKey: Preferences.x509CA)
            defaults.set("User Auth", forKey: Preferences.template)
            defaults.set(true, forKey: Preferences.verbose)
            defaults.set("", forKey: Preferences.userCommandHotKey1)
            defaults.set("", forKey: Preferences.userCommandName1)
            defaults.set("", forKey: Preferences.userCommandTask1)
            defaults.set(7200, forKey: Preferences.secondsToRenew)
            defaults.set(1, forKey: "RenewTickets")
            defaults.set("", forKey: Preferences.autoConfigure)

        default:
            // see if we're on AD
            getADSettings()
            break
        }
    }

    if defaults.bool(forKey: Preferences.loginItem) {
        //TODO: Test this to make sure it actually does what I think it will. This should return the value of the key if found, otherwise false.
        addToLoginItems()
    }
}

private func getADSettings() {

    let myADConfig = cliTask("/usr/sbin/dsconfigad -show").components(separatedBy: "\n")

    if myADConfig.count > 0 {
        for line in myADConfig {
            if line.contains("Active Directory Domain") {
                let myDomain = (line as NSString).substring(from: 35)
                defaults.set(myDomain, forKey: Preferences.aDDomain)
                defaults.set(myDomain.uppercased(), forKey: Preferences.kerberosRealm)
                //defaults.setObject("", forKey: "InternalSite")
                //defaults.setObject("", forKey: "InternalSiteIP")
                defaults.set(false, forKey: Preferences.verbose)
                defaults.set("", forKey: Preferences.userCommandHotKey1)
                defaults.set("", forKey: Preferences.userCommandName1)
                defaults.set("", forKey: Preferences.userCommandTask1)
                defaults.set(7200, forKey: Preferences.secondsToRenew)
                defaults.set(1, forKey: "RenewTickets")
                break
            }
        }
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
