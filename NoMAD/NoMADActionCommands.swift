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
        
        switch action.lowercased() {
        case "path" :
            result = cliTask(options)
        case "app" :
            _ = try? NSWorkspace.shared.launchApplication(at: URL.init(fileURLWithPath: options), options: NSWorkspace.LaunchOptions.default, configuration: [:] )
        case "url" :
            NSWorkspace.shared.open(URL.init(string: options)!)
        case "file" :
            result = FileManager().fileExists(atPath: options).description
        case "ping" :
            let pingResult = cliTask("/sbin/ping -q -c 4 -t 3 -o " + options)
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
        case "groups" :
            if (defaults.array(forKey: Preferences.groups) as! [String]).contains(options) {
                result = "true"
            } else {
                return "false"
            }
        default :
            break
        }
        return result
    }
