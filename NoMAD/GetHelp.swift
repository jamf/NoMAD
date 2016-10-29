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
		
        if let getHelpType = defaults.string(forKey: "GetHelpType") {
            if let getHelpOptions = defaults.string(forKey: "GetHelpOptions") {
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
					let url = URL(string: myURL)
					NSWorkspace.shared().open( url! )
                }
                
            case "App":
                cliTask("/usr/bin/open " + getHelpOptions.replacingOccurrences(of: " ", with: "\\ ") )
            
            default:
				let url = URL(string: "http://www.apple.com/support")!
				NSWorkspace.shared().open( url )
            }
        } else {
            NSLog("Invalid getHelpType or getHelpOptions, defaulting to www.apple.com/support")
			let url = URL(string: "http://www.apple.com/support")!
			NSWorkspace.shared().open( url )
			
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
