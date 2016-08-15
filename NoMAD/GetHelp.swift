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
    
    var getHelpType: String
    var getHelpOptions: String
    var enabled: Bool
    
    init() {
        getHelpType = ""
        getHelpOptions = ""
        enabled = false
        
        if let getHelpType = defaults.stringForKey("GetHelpType") {
            if let getHelpOptions = defaults.stringForKey("GetHelpOptions") {
                self.getHelpOptions = getHelpOptions
                self.getHelpType = getHelpType

                enabled = true;
            }
            
            else  {
                print("Missing getHelpOptions key")
                self.getHelpType = ""
                self.getHelpOptions = ""
                enabled = false
            }
        }
    }
    
    func getHelp() {
        
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
                    cliTask("/usr/bin/open " + myURL )
                }
                
            case "App":
                cliTask("/usr/bin/open " + getHelpOptions.stringByReplacingOccurrencesOfString(" ", withString: "\\ ") )
            
            default:
                
                // we will most likely never get here...
                cliTask("/usr/bin/open http://www.apple.com/support")
                
            }
        }
        
        else {
            NSLog("Invalid getHelpType or getHelpOptions, defaulting to www.apple.com/support")
            cliTask("/usr/bin/open http://www.apple.com/support")
        }
    }
    
    private func subVariables( url: String ) -> String? {
        // TODO: get e-mail address as a variable
        
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
    }
}