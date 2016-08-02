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
        getHelpType = defaults.stringForKey("GetHelpType") ?? ""
        getHelpOptions = defaults.stringForKey("GetHelpOptions") ?? ""
        
        if ( getHelpType == "" ) {
            enabled = false
        } else {
            enabled = true
        }
    }
    
    func getHelp() {
        switch getHelpType {
        case "Bomgar":
            let myURL = subVariables(getHelpOptions)
            cliTask("curl -o /tmp/BomgarClient " + myURL )
            cliTaskNoTerm("/usr/bin/unzip -o -d /tmp /tmp/BomgarClient")
            cliTask("/usr/bin/open /tmp/Bomgar/Double-Click\\ To\\ Start\\ Support\\ Session.app")
            
        case "URL":
            let myURL = subVariables(getHelpOptions)
            cliTask("/usr/bin/open " + myURL )
            
        case "App":
            cliTask("/usr/bin/open " + getHelpOptions.stringByReplacingOccurrencesOfString(" ", withString: "\\ ") )
        
        default:
        cliTask("curl -o /tmp/BomgarClient https://bomgar.bomgar.com/api/start_session -A \"Mozilla/5.0\\ (Macintosh;\\ Intel\\ Mac\\ OS\\ X\\ 10_11_4)\\ AppleWebKit/601.5.17\\ (KHTML,\\ like\\ Gecko)\\ Version/9.1\\ Safari/601.5.17\" -d issue_menu=1 -d session.custom.external_key=NoMAD -d session.custom.full_name=" + String(defaults.stringForKey("displayName")!.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())) + " -d session.custom.serial_number=" + getSerial() + " -d customer.company=" + defaults.stringForKey("ADDomain")! )
        cliTaskNoTerm("/usr/bin/unzip -o -d /tmp /tmp/BomgarClient")
        cliTask("/usr/bin/open /tmp/Bomgar/Double-Click\\ To\\ Start\\ Support\\ Session.app")
        }
    }
    
    private func subVariables( url: String ) -> String {
        //let email = UserInfoAPI.getLDAPInfo(<#T##UserInfoAPI#>)
        let domain = defaults.stringForKey("ADDomain")!
        let fullName = defaults.stringForKey("displayName")!.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
        //let shortName = userInfoAPI.connectionData["userPrincipal"]!
        let serial = getSerial()
        
        let subURL = url.stringByReplacingOccurrencesOfString("<<domain>>", withString: domain)
        let subURL1 = subURL.stringByReplacingOccurrencesOfString("<<fullname>>", withString: fullName!)
        let subURL2 = subURL1.stringByReplacingOccurrencesOfString("<<serial>>", withString: serial)
        return subURL2
    }
}