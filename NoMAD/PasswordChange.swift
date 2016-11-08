//
//  PasswordChange.swift
//  NoMAD
//
//  Created by Joel Rennich on 7/25/16.
//  Copyright © 2016 Trusource Labs. All rights reserved.
//

//
// Class to manage what the Password Change menu option does
// Mostly cloned from the GetHelp class
//

import Foundation


class PasswordChange {

    var passwordChangeType: String
    var passwordChangeOptions: String
    var enabled: Bool

    init() {
        passwordChangeType = ""
        passwordChangeOptions = ""
        enabled = false

        if let passwordChangeType = defaults.string(forKey: "PasswordChangeType") {
            if let passwordChangeOptions = defaults.string(forKey: "PasswordChangeOptions") {
                self.passwordChangeOptions = passwordChangeOptions
                self.passwordChangeType = passwordChangeType

                enabled = true;
            } else {
                print("Missing PasswordChangeOptions key")
                self.passwordChangeType = ""
                self.passwordChangeOptions = ""
                enabled = false
            }
        } else {
            print("Missing PasswordChangeType key")
        }
    }

    func passwordChange() {

        if passwordChangeType != "" && passwordChangeOptions != "" {
            switch passwordChangeType {
            case "Task":
                let result = cliTask(passwordChangeOptions)
                myLogger.logit(.base, message: result)

            case "URL":
                if let myURL = subVariables(passwordChangeOptions) {
                    let url = URL(string: myURL)
                    NSWorkspace.shared().open( url! )
                }

            case "App":
                cliTask("/usr/bin/open " + passwordChangeOptions.replacingOccurrences(of: " ", with: "\\ ") )

            case "None":
                myLogger.logit(.base, message: "No password changes allowed.")

            default:
                let url = URL(string: "http://www.apple.com/support")!
                NSWorkspace.shared().open( url )
            }
        } else {
            myLogger.logit(.debug, message: "Invalid PasswordChangeType or PasswordChangeOptions, defaulting to change via Kerberos.")
        }
    }

    fileprivate func subVariables( _ url: String ) -> String? {
        // TODO: get e-mail address as a variable
        var createdURL = url;
        if let domain = defaults.string(forKey: "ADDomain") {
            createdURL = createdURL.replacingOccurrences(of: "<<domain>>", with: domain)
        }

        //TODO: this crashes if displayName is empty
        // Should be fixed... needs to be tested.
        if (defaults.string(forKey: "displayName") != nil) {
            let fullName = defaults.string(forKey: "displayName")!.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)
            createdURL = createdURL.replacingOccurrences(of: "<<fullname>>", with: fullName!)
        }
        if let serial = getSerial().addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) {
            createdURL = createdURL.replacingOccurrences(of: "<<serial>>", with: serial)
        }
        let shortName = defaults.string(forKey: "UserShortName") ?? ""
        createdURL = createdURL.replacingOccurrences(of: "<<shortname>>", with: shortName)

        return createdURL
    }
}
