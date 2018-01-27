//
//  NoMADActionCommands.swift
//  NoMAD
//
//  Created by Joel Rennich on 1/24/18.
//  Copyright © 2018 Orchard & Grove Inc. All rights reserved.
//

import Foundation

// class to keep all of the possible actions


public enum ActionType {
    case path, app, url, ping, SRV, seperator, alert, notify, file, groups
}

    // run an action
    
public func runActionCommand( action: String, options: String) -> String {
        
        var result = ""
    
    if options == "none" {
        return "error"
    }
    
    let optionsClean = options.variableSwap()
        
        switch action.lowercased() {
        case "path" :
            result = cliTask(optionsClean)
        case "app" :
            _ = try? NSWorkspace.shared.launchApplication(at: URL.init(fileURLWithPath: optionsClean), options: NSWorkspace.LaunchOptions.default, configuration: [:] )
        case "url" :
            NSWorkspace.shared.open(URL.init(string: optionsClean)!)
        case "file" :
            result = FileManager().fileExists(atPath: optionsClean).description
        case "ping" :
            let pingResult = cliTask("/sbin/ping -q -c 4 -t 3 -o " + optionsClean)
            let pingResultParts = pingResult.components(separatedBy: ",")
            
            for part in pingResultParts {
                if part.contains("packets received") {
                    if part == "0 packets received" {
                        return "false"
                    } else {
                        return "true"
                    }
                }
            }
            return "false"

        case "SRV" :
            // TODO: use SRV lookup class here
            break
        case "adgroup" :
            if (defaults.array(forKey: Preferences.groups) as! [String]).contains(optionsClean) {
                result = "true"
            } else {
                return "false"
            }
        case "alert" :
            // show an alert only if we have options
            
            if optionsClean == "" {
                break
            }
            
            let myAlert = NSAlert()
            myAlert.messageText = optionsClean
            
            // move to the foreground since we're displaying UI
            
            DispatchQueue.main.async {
                myAlert.runModal()
            }
        case "notify" :
            
            let notification = NSUserNotification()
            notification.informativeText = options
            notification.hasReplyButton = false
            notification.hasActionButton = false
            notification.soundName = NSUserNotificationDefaultSoundName
            NSUserNotificationCenter.default.deliver(notification)
        
        case "false" :
            return "false"
        default :
            break
        }
        return result
    }
