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

    if let autoConfigure = defaults.string(forKey: AutoConfigure) {
        switch autoConfigure {
        case "TSL":
            defaults.set("trusourcelabs.com", forKey: ADDomain)
            defaults.set("TRUSOURCELABS.COM", forKey: "KerberosRealm")
            //defaults.setObject("jupiter.trusourcelabs.com", forKey: "InternalSite")
            //defaults.setObject("192.168.32.43", forKey: "InternalSiteIP")
            defaults.set(true, forKey: "Verbose")
            defaults.set("", forKey: "userCommandHotKey1")
            defaults.set("", forKey: "userCommandName1")
            defaults.set("", forKey: "userCommandTask1")
            defaults.set(7200, forKey: "secondsToRenew")
            defaults.set(1, forKey: "RenewTickets")
            defaults.set("", forKey: AutoConfigure)

        case "JODA":
            defaults.set("jodapro.com", forKey: ADDomain)
            defaults.set("JODAPRO.COM", forKey: "KerberosRealm")
            //defaults.setObject("in-or-out.jodapro.com", forKey: "InternalSite")
            //defaults.setObject("1.1.1.1", forKey: "InternalSiteIP")
            defaults.set("2k12.jodapro.com", forKey: "x509CA")
            defaults.set("User Auth", forKey: "Template")
            defaults.set(true, forKey: "Verbose")
            defaults.set("", forKey: "userCommandHotKey1")
            defaults.set("", forKey: "userCommandName1")
            defaults.set("", forKey: "userCommandTask1")
            defaults.set(7200, forKey: "secondsToRenew")
            defaults.set(1, forKey: "RenewTickets")
            defaults.set("", forKey: AutoConfigure)

        default:
            // see if we're on AD
            getADSettings()
            break
        }
    }

    if defaults.bool(forKey: "LoginItem") {
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
                defaults.set(myDomain, forKey: ADDomain)
                defaults.set(myDomain.uppercased(), forKey: "KerberosRealm")
                //defaults.setObject("", forKey: "InternalSite")
                //defaults.setObject("", forKey: "InternalSiteIP")
                defaults.set(false, forKey: "Verbose")
                defaults.set("", forKey: "userCommandHotKey1")
                defaults.set("", forKey: "userCommandName1")
                defaults.set("", forKey: "userCommandTask1")
                defaults.set(7200, forKey: "secondsToRenew")
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

    defaults.set(false, forKey: "LoginItem")

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
