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
    var userCertDate = NSDate()
    var groups = [String]()
    
    let myLDAPServers = LDAPServers()
    let myTickets = KlistUtil()
    
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
    }
    
    func checkNetwork() -> Bool {
        myLDAPServers.check()
        return myLDAPServers.returnState()
    }
    
    func checkTickets() {
        
    }
    
    func getUserInfo() {
        
        // 1. check if AD can be reached
        
        var canary = true
        
        myTickets.getDetails()
        
        if myLDAPServers.currentState {
            status = "Connected"
            connected = true
        } else {
            status = "Not connected"
            connected = false
            NSLog("Not connected to the network")
        }
        
        // 2. check for tickets
        
        if myTickets.state {
            tickets = true
            userPrincipal = myTickets.principal
            realm = defaults.stringForKey("KerberosRealm")!
            if userPrincipal.containsString(realm) {
                userPrincipalShort = userPrincipal.stringByReplacingOccurrencesOfString("@" + realm, withString: "")
                loggedIn = true
                status = "Logged In"
                NSLog("Logged in.")
            } else {
                loggedIn = false
                NSLog("No ticket for realm.")
            }
        } else {
            tickets = false
            loggedIn = false
            NSLog("No tickets")
        }
        
        // 3. if connected and with tickets, get password aging information
        
        if connected && loggedIn {
            
            var passwordSetDate = ""
            
            do {
                passwordSetDate = try myLDAPServers.getLDAPInformation("pwdLastSet", searchTerm: "sAMAccountName=" + userPrincipalShort)
            } catch {
                passwordSetDate = ""
                NSLog("We shouldn't have gotten here... tell Joel")
                canary = false
            }
            
            if canary {
            userPasswordSetDate = NSDate(timeIntervalSince1970: (Double(Int(passwordSetDate)!))/10000000-11644473600)
            
            // Now get default password expiration time - this may not be set for environments with no password cycling requirements
            
            NSLog("Getting password aging info")
            
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
                    let serverPasswordExpirationDefault = Double(0)
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
        }
        
        // TODO: figure out if the password changed without us knowing
        
        // 4. if connected and with tickets, get all of user information
        
        if connected && tickets && canary {
            let userHomeTemp = try! myLDAPServers.getLDAPInformation("homeDirectory", searchTerm: "sAMAccountName=" + userPrincipalShort)
            userHome = userHomeTemp.stringByReplacingOccurrencesOfString("\\", withString: "/")
            userDisplayName = try! myLDAPServers.getLDAPInformation("displayName", searchTerm: "sAMAccountName=" + userPrincipalShort)
            
            groups.removeAll()
            
            let groupsTemp = try! myLDAPServers.getLDAPInformation("memberOf", searchTerm: "sAMAccountName=" + userPrincipalShort ).componentsSeparatedByString(", ")
            for group in groupsTemp {
                let a = group.componentsSeparatedByString(",")
                let b = a[0].stringByReplacingOccurrencesOfString("CN=", withString: "") as String
                groups.append(b)
            }
            
            NSLog("You are a member of: " + groups.joinWithSeparator(", ") )
            // set defaults for these
            
            defaults.setObject(userHome, forKey: "userHome")
            defaults.setObject(userDisplayName, forKey: "displayName")
            defaults.setObject(userPrincipalShort, forKey: "userPrincipal")
            defaults.setObject(userPrincipalShort, forKey: "LastUser")
            defaults.setObject(userPasswordExpireDate, forKey: "LastPasswordExpireDate")
        }
        }


}
