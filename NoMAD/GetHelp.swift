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
                
                if let displayNameKey: String = defaults.stringForKey("displayName") {
                    if let domain = defaults.stringForKey("ADDomain") {
                        
                        let displayName: String = displayNameKey.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())!
                        
                        let curl = "curl -o /tmp/BomgarClient https://bomgar.bomgar.com/api/start_session -A \"Mozilla/5.0\\ (Macintosh;\\ Intel\\ Mac\\ OS\\ X\\ 10_11_4)\\ AppleWebKit/601.5.17\\ (KHTML,\\ like\\ Gecko)\\ Version/9.1\\ Safari/601.5.17\" -d issue_menu=1 -d session.custom.external_key=NoMAD -d session.custom.full_name="
                        
                        let serial = " -d session.custom.serial_number=" + getSerial()
                        
                        cliTask(curl + displayName + serial + " -d customer.company=" + domain)
                        cliTaskNoTerm("/usr/bin/unzip -o -d /tmp /tmp/BomgarClient")
                        cliTask("/usr/bin/open /tmp/Bomgar/Double-Click\\ To\\ Start\\ Support\\ Session.app")
                    }
                }
            }
        }
        
        else {
            print("Invalid getHelpType or getHelpOptions")
        }
    }
    
    private func subVariables( url: String ) -> String? {
        //let email = UserInfoAPI.getLDAPInfo(<#T##UserInfoAPI#>)
        
        if let domain = defaults.stringForKey("ADDomain") {
            if let fullName = defaults.stringForKey("displayName")!.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet()) {
                //let shortName = userInfoAPI.connectionData["userPrincipal"]!
                let serial = getSerial()
                
                let subURL = url.stringByReplacingOccurrencesOfString("<<domain>>", withString: domain)
                let subURL1 = subURL.stringByReplacingOccurrencesOfString("<<fullname>>", withString: fullName)
                let subURL2 = subURL1.stringByReplacingOccurrencesOfString("<<serial>>", withString: serial)

                return subURL2
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