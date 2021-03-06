//
//  GetHelp.swift
//  NoMAD
//
//  Created by Joel Rennich on 7/25/16.
//  Copyright © 2016 Trusource Labs. All rights reserved.
//

//
// Class to manage what the Get Help menu option does
//

import Foundation

//TODO: Move to a standard URL for the Bomgar client so we can use the standard URLSession tools.
class GetHelp {

    func getHelp() {
        if let getHelpType = defaults.string(forKey: Preferences.getHelpType),
            let getHelpOptions = defaults.string(forKey: Preferences.getHelpOptions) {

            if getHelpType.characters.count > 0 && getHelpOptions.characters.count > 0 {
                switch getHelpType {
                case "Bomgar":
                    if let myURL = subVariables(getHelpOptions) {
                        OperationQueue.main.addOperation() {
                            cliTask("curl -o /tmp/BomgarClient " + myURL )
                            cliTaskNoTerm("/usr/bin/unzip -o -d /tmp /tmp/BomgarClient")
                            cliTask("/usr/bin/open /tmp/Bomgar/Double-Click\\ To\\ Start\\ Support\\ Session.app")
                        }
                    }
                case "URL":
                        guard let url = URL(string: getHelpOptions) else {
                            myLogger.logit(.base, message: "Could not create help URL.")
                            break
                        }
                        NSWorkspace.shared().open(url)
                case "Path":
                    cliTask(getHelpOptions.replacingOccurrences(of: " ", with: "\\ "))
                case "App":
                    NSWorkspace.shared().launchApplication(getHelpOptions)
                default:
                    myLogger.logit(.info, message: "Invalid getHelpType or getHelpOptions, defaulting to www.apple.com/support")
                    openDefaultHelpURL()
                }
            } else {
                myLogger.logit(.info, message: "No help options set, defaulting to www.apple.com/support")
                openDefaultHelpURL()
            }
        }
    }

    fileprivate func openDefaultHelpURL() {
        guard let url = URL(string: "http://www.apple.com/support") else {
            myLogger.logit(.base, message: "Could not create default help URL.")
            return
        }
        NSWorkspace.shared().open(url)
    }

    fileprivate func subVariables(_ url: String) -> String? {
        // TODO: get e-mail address as a variable
        var createdURL = url

        guard let domain = defaults.string(forKey: Preferences.aDDomain),
            let fullName = defaults.string(forKey: Preferences.displayName)?.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed),
            let serial = getSerial().addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed),
            let shortName = defaults.string(forKey: Preferences.userShortName)
            else {
                myLogger.logit(.base, message: "Could not create Bomgar launch string.")
                return nil
        }
        createdURL = createdURL.replacingOccurrences(of: "<<domain>>", with: domain)
        createdURL = createdURL.replacingOccurrences(of: "<<fullname>>", with: fullName)
        createdURL = createdURL.replacingOccurrences(of: "<<serial>>", with: serial)
        createdURL = createdURL.replacingOccurrences(of: "<<shortname>>", with: shortName)
        return createdURL
    }
}
