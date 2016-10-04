//
//  UserInformation.swift
//  NoMAD
//
//  Created by Joel Rennich on 8/20/16.
//  Copyright © 2016 Trusource Labs. All rights reserved.
//

import Foundation

class UserInformation {
    
    // set up defaults for the domain
    
    var status = "Not Connected"
    var domain = ""
    var realm = ""
    
    var passwordAging = false
    var connected = false
    var tickets = false
    var loggedIn = false
    
    var serverPasswordExpirationDefault: Double
    
    // User Info
    var userShortName: String
    var userLongName: String
    var userPrincipal: String
    var userPrincipalShort: String
    var userDisplayName: String
    var userPasswordSetDate = NSDate()
    var userPasswordExpireDate = NSDate()
    var userHome: String
    
    var lastSetDate = NSDate()
    
    var userCertDate = NSDate()
    var groups = [String]()
    
    let myLDAPServers = LDAPServers()
    
    var UserPasswordSetDates = [String : AnyObject ]()
    
    init() {
        // zero everything out
        
        userShortName = ""
        userLongName = ""
        userPrincipal = ""
        userPrincipalShort = ""
        userPasswordSetDate = NSDate()
        userPasswordExpireDate = NSDate()
        userHome = ""
        userCertDate = NSDate()
        serverPasswordExpirationDefault = Double(0)
        userDisplayName = ""
        if defaults.dictionaryForKey("UserPasswordSetDates") != nil {
            UserPasswordSetDates = defaults.dictionaryForKey("UserPasswordSetDates")!
        }
    }
    
    func checkNetwork() -> Bool {
        myLDAPServers.check()
        return myLDAPServers.returnState()
    }
    
    func getUserInfo() {
        
        // 1. check if AD can be reached
        
        var canary = true
        checkNetwork()
        
        //myLDAPServers.tickets.getDetails()
        
        if myLDAPServers.currentState {
            status = "Connected"
            connected = true
        } else {
            status = "Not connected"
            connected = false
            myLogger.logit(0, message: "Not connected to the network")
        }
        
        // 2. check for tickets
        
        if myLDAPServers.tickets.state {
            userPrincipal = myLDAPServers.tickets.principal
            realm = defaults.stringForKey("KerberosRealm")!
            if userPrincipal.containsString(realm) {
                userPrincipalShort = userPrincipal.stringByReplacingOccurrencesOfString("@" + realm, withString: "")
                status = "Logged In"
                myLogger.logit(0, message: "Logged in.")
            } else {
                myLogger.logit(0, message: "No ticket for realm.")
            }
        } else {
            myLogger.logit(0, message: "No tickets")
        }
        
        // 3. if connected and with tickets, get password aging information
        
        if connected && myLDAPServers.tickets.state {
            
            var passwordSetDate = ""
            
            do {
                passwordSetDate = try myLDAPServers.getLDAPInformation("pwdLastSet", searchTerm: "sAMAccountName=" + userPrincipalShort)
            } catch {
                passwordSetDate = ""
                myLogger.logit(0, message: "We shouldn't have gotten here... tell Joel")
                canary = false
            }
            
            if canary {
				if (passwordSetDate != "") {
					userPasswordSetDate = NSDate(timeIntervalSince1970: (Double(Int(passwordSetDate)!))/10000000-11644473600)
				}
				
                // Now get default password expiration time - this may not be set for environments with no password cycling requirements
                
                myLogger.logit(1, message: "Getting password aging info")
                
                // First try msDS-UserPasswordExpiryTimeComputed
                
                let computedExpireDateRaw = try! myLDAPServers.getLDAPInformation("msDS-UserPasswordExpiryTimeComputed", searchTerm: "sAMAccountName=" + userPrincipalShort)
                
                if ( Int(computedExpireDateRaw) == 9223372036854775807 ) {
                    
                    // password doesn't expire
                    
                    passwordAging = false
                    defaults.setObject(false, forKey: "UserAging")
                    
                    // set expiration to set date
                    
                    userPasswordExpireDate = NSDate()
                    
                } else if ( Int(computedExpireDateRaw) != nil ) {
                    
                    // password expires
                    
                    passwordAging = true
                    defaults.setObject(true, forKey: "UserAging")
                    let computedExpireDate = NSDate(timeIntervalSince1970: (Double(Int(computedExpireDateRaw)!))/10000000-11644473600)
                    userPasswordExpireDate = computedExpireDate
                    
                } else {
                    
                    // need to go old skool
                    
                    let passwordExpirationLength = try! myLDAPServers.getLDAPInformation("maxPwdAge", baseSearch: true )
                    
                    if ( passwordExpirationLength.characters.count > 15 ) {
                        //serverPasswordExpirationDefault = Double(0)
                        passwordAging = false
                    } else if ( passwordExpirationLength != "" ){
                        
                        // now check the users uAC to see if they are exempt
                        
                        let userPasswordUACFlag = try! myLDAPServers.getLDAPInformation("userAccountControl", searchTerm: "sAMAccountName=" + userPrincipalShort)
                        
                        if ~~( Int(userPasswordUACFlag)! & 0x10000 ) {
                            passwordAging = false
                            defaults.setObject(false, forKey: "UserAging")
                        } else {
                            serverPasswordExpirationDefault = Double(abs(Int(passwordExpirationLength)!)/10000000)
                            passwordAging = true
                            defaults.setObject(true, forKey: "UserAging")
                        }
                    } else {
                        serverPasswordExpirationDefault = Double(0)
                        passwordAging = false
                    }
                    userPasswordExpireDate = userPasswordSetDate.dateByAddingTimeInterval(serverPasswordExpirationDefault)
                }
            }
            
            // now to see if the password has changed without NoMAD knowing
            
            if (UserPasswordSetDates[userPrincipal] != nil) && (String(UserPasswordSetDates[userPrincipal]) != "just set" ) {
                
                // user has been previously set so we can check it
                
				if ((UserPasswordSetDates[userPrincipal] as? NSDate )! != userPasswordSetDate) {
					myLogger.logit(0, message: "Password was changed underneath us.")
					// TODO: Do something if we get here
					
					// record the new password set date
					
					UserPasswordSetDates[userPrincipal] = userPasswordSetDate
					defaults.setObject(UserPasswordSetDates, forKey: "UserPasswordSetDates")
                
                }
            } else {
                UserPasswordSetDates[userPrincipal] = userPasswordSetDate
                defaults.setObject(UserPasswordSetDates, forKey: "UserPasswordSetDates")
            }
        }
        
        // 4. if connected and with tickets, get all of user information
        
        if connected && myLDAPServers.tickets.state && canary {
            let userHomeTemp = try! myLDAPServers.getLDAPInformation("homeDirectory", searchTerm: "sAMAccountName=" + userPrincipalShort)
            userHome = userHomeTemp.stringByReplacingOccurrencesOfString("\\", withString: "/")
            userDisplayName = try! myLDAPServers.getLDAPInformation("displayName", searchTerm: "sAMAccountName=" + userPrincipalShort)
            
            groups.removeAll()
            
            let groupsTemp = try! myLDAPServers.getLDAPInformation("memberOf", searchTerm: "sAMAccountName=" + userPrincipalShort ).componentsSeparatedByString(", ")
            for group in groupsTemp {
                let a = group.componentsSeparatedByString(",")
                let b = a[0].stringByReplacingOccurrencesOfString("CN=", withString: "") as String
                if b != "" {
                    groups.append(b)
                }
            }
            
            myLogger.logit(1, message: "You are a member of: " + groups.joinWithSeparator(", ") )
            // set defaults for these
            
            defaults.setObject(userHome, forKey: "userHome")
            defaults.setObject(userDisplayName, forKey: "displayName")
            defaults.setObject(userPrincipalShort, forKey: "userPrincipal")
            defaults.setObject(userPrincipalShort, forKey: "LastUser")
            defaults.setObject(userPasswordExpireDate, forKey: "LastPasswordExpireDate")
            defaults.setObject(groups, forKey: "Groups")
        }
    }
    
    
}
