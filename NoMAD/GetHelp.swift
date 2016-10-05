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
            } else {
                print("Missing getHelpOptions key")
                self.getHelpType = ""
                self.getHelpOptions = ""
                enabled = false
            }
		} else {
			print("Missing getHelpType key")
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
					let url = NSURL(string: myURL)
					NSWorkspace.sharedWorkspace().openURL( url! )
                }
                
            case "App":
                cliTask("/usr/bin/open " + getHelpOptions.stringByReplacingOccurrencesOfString(" ", withString: "\\ ") )
            
            default:
				let url = NSURL(string: "http://www.apple.com/support")!
				NSWorkspace.sharedWorkspace().openURL( url )
            }
        } else {
            NSLog("Invalid getHelpType or getHelpOptions, defaulting to www.apple.com/support")
			let url = NSURL(string: "http://www.apple.com/support")!
			NSWorkspace.sharedWorkspace().openURL( url )
			
        }
    }
    
    private func subVariables( url: String ) -> String? {
        // TODO: get e-mail address as a variable
		var createdURL = url;
		if let domain = defaults.stringForKey("ADDomain") {
			createdURL = createdURL.stringByReplacingOccurrencesOfString("<<domain>>", withString: domain)
		}
        
        //TODO: this crashes if displayName is empty
		if let fullName = defaults.stringForKey("displayName")!.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet()) {
			createdURL = createdURL.stringByReplacingOccurrencesOfString("<<fullname>>", withString: fullName)
		}
		if let serial = getSerial().stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet()) {
			createdURL = createdURL.stringByReplacingOccurrencesOfString("<<serial>>", withString: serial)
		}
		let shortName = defaults.stringForKey("UserShortName") ?? ""
		createdURL = createdURL.stringByReplacingOccurrencesOfString("<<shortname>>", withString: shortName)
		
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
