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

class GetHelp {

    func getHelp() {
        if let getHelpType = defaults.string(forKey: Preferences.getHelpType),
            let getHelpOptions = defaults.string(forKey: Preferences.getHelpOptions) {

            if getHelpType != "" && getHelpOptions != "" {
                switch getHelpType {
                case "Bomgar":
                    if let myURL = subVariables(getHelpOptions) {
                        cliTask("curl -o /tmp/BomgarClient " + myURL )
                        cliTaskNoTerm("/usr/bin/unzip -o -d /tmp /tmp/BomgarClient")
                        cliTask("/usr/bin/open /tmp/Bomgar/Double-Click\\ To\\ Start\\ Support\\ Session.app")
                    }
                case "URL":
                    if let myURL = subVariables(getHelpOptions) {
                        let url = URL(string: myURL)
                        NSWorkspace.shared().open(url!)
                    }
                case "Path":
                    cliTask("/usr/bin/open " + getHelpOptions.replacingOccurrences(of: " ", with: "\\ ") )
                case "App":
                    NSWorkspace.shared().launchApplication(getHelpOptions)
                default:
                    myLogger.logit(.info, message: "Invalid getHelpType or getHelpOptions, defaulting to www.apple.com/support")
                    let url = URL(string: "http://www.apple.com/support")!
                    NSWorkspace.shared().open(url)
                }
            } else {
                myLogger.logit(.info, message: "No help options set, defaulting to www.apple.com/support")
                let url = URL(string: "http://www.apple.com/support")!
                NSWorkspace.shared().open(url)
            }
        }
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
        /*
         if let domain = defaults.stringForKey("ADDomain") {
         if let fullName = defaults.stringForKey("displayName")!.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet()) {
         let shortName = defaults.stringForKey("UserShortName") ?? ""
         let serial = getSerial()

         let subURL = url.stringByReplacingOccurrencesOfString("<<domain>>", withString: domain)
         let subURL1 = subURL.stringByReplacingOccurrencesOfString("<<fullname>>", withString: fullName)
         let subURL2 = subURL1.stringByReplacingOccurrencesOfString("<<serial>>", withString: serial)
         let subURL3 = subURL2.stringByReplacingOccurrencesOfString("<<shortname>>", withString: shortName)

         return subURL3
         }

         else {
         print ("displayName key failure")

         return ""
         }
         }

         print("ADDomain key failure")
         
         return ""
         */
    }
}
