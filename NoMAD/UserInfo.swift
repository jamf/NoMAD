//
//  UserInfo.swift
//  NoMAD
//
//  Created by Admin on 7/13/16.
//  Copyright © 2016 Trusource Labs. All rights reserved.
//

import Foundation

struct UserInfo: CustomStringConvertible {
    
    // Network Info
    var connectionTestURL: String
    var connectionTestResult: String
    
    // AD Domain Info
    var realm: String
    var domain : String
    var ldapServer : String
    var ldapServerNamingContext : String
    var serverPasswordExpireDefaults = NSTimeInterval()
    var passwordAging: Bool = false
    
    // Connection Info
    var isConnected : Bool = false
    var isLoggedIn : Bool = false
    var status : String
    
    // User Info
    var userShortName: String
    var userLongName: String
    var userPrincipal: String
    var userPrincipalShort: String
    var userPasswordSetDate = NSDate()
    var userPasswordExpireDate = NSDate()
    var userHome: String
    var userCertDate = NSDate()
    var userTicketExpireTime = NSDate()
    
    var description: String {
        return "\(userPrincipalShort), \(ldapServer), \(realm), \(userPasswordExpireDate) "
    }
    
}

class UserInfoAPI {
    
    // where all the magic happens - set up some defaults
    
    var connectionData = [String: String ]()
    var connectionDates = [String: NSDate]()
    var connectionFlags = [String: Bool]()
    var serverPasswordExpirationDefault = NSTimeInterval()
    
    let myLDAPServers = LDAPServers()
    let myTickets = KlistUtil()
    
    // update information on network changes and other
    
    func update( success: (UserInfo) -> UserInfo? ) {
        
        connectionData["domain"] = defaults.stringForKey("ADDomain")!
        connectionData["realm"] = defaults.stringForKey("realm")
        connectionData["connectionTestURL"] = defaults.stringForKey("InternalSite")!
        connectionData["connectionTestResult"] = defaults.stringForKey("InternalSiteIP")!
        
        // Log where we are
        
        if defaults.integerForKey("Verbose") >= 1 {
            NSLog("Checking State")
            NSLog("Domain: " + connectionData["domain"]! )
            NSLog("Realm: " + connectionData["realm"]! )
            NSLog("Connection Test URL: " + connectionData["connectionTestURL"]!)
            NSLog("Connection Test Result: " + connectionData["connectionTestResult"]!)
        }
        
        if let userinfo = self.checkAll() {
            success(userinfo)
        }
    }
    
    // do a full check of where we are
    
    func checkAll() -> UserInfo? {
        
        connectionData["domain"] = defaults.stringForKey("ADDomain")!
        connectionData["realm"] = defaults.stringForKey("KerberosRealm")
        connectionData["connectionTestURL"] = defaults.stringForKey("InternalSite")!
        connectionData["connectionTestResult"] = defaults.stringForKey("InternalSiteIP")!
        
        do {
            try ConnectionStatus(connectionData["connectionTestURL"]!, connectionTestResult: connectionData["connectionTestResult"]!)
        } catch {
            connectionFlags["isConnected"] = false
            connectionData["ldapServer"] = ""
            connectionData["ldapServerNamingContext"] = ""
            connectionDates["serverPasswordExpireDefaults"] = NSDate()
            connectionData["status"] = "Not Connected"
            
            // Log where we are
            
            if defaults.integerForKey("Verbose") >= 1 {
                NSLog("Outside of network. Can't check for AD information.")
            }
            
        }
        do {
            try TGTPrincpalName(connectionData["realm"]!)
        } catch {
            connectionFlags["isLoggedIn"] = false
            connectionData["userPrincipal"] = "No User"
            connectionData["userPrincipalShort"] = "No User"
            connectionData["ldapServer"] = ""
            connectionData["ldapServerNamingContext"] = ""
            connectionDates["userPasswordSetDate"] = NSDate()
            connectionDates["userPasswordExpireDate"] = NSDate()
            serverPasswordExpirationDefault = NSTimeInterval()
            connectionData["userHome"] = ""
            connectionFlags["passwordAging"] = false
            connectionDates["userTicketExpireTime"] = NSDate()
            
            // Log where we are
            
            if defaults.integerForKey("Verbose") >= 1 {
                NSLog("On network, but no Kerberos Ticket.")
            }
        }
        
        if ( connectionFlags["isLoggedIn"] == true ) {
            do {
                try getLDAPInfo( connectionData["domain"]!)
            } catch {
                connectionData["ldapServer"] = ""
                connectionData["ldapServerNamingContext"] = ""
                connectionDates["serverPasswordExpireDefaults"] = NSDate()
                connectionData["userPrincipal"] = "No User"
                connectionData["userPrincipalShort"] = "No User"
                connectionDates["userPasswordSetDate"] = NSDate()
                connectionDates["userPasswordExpireDate"] = NSDate()
                serverPasswordExpirationDefault = NSTimeInterval()
                connectionData["userHome"] = ""
                connectionFlags["passwordAging"] = false
                connectionDates["userTicketExpireTime"] = NSDate()
                
                // Log where we are
                
                if defaults.integerForKey("Verbose") >= 1 {
                    NSLog("On network, have Kerberos ticket, but can't find AD.")
                }
            }
            
            do {
                try connectionData["userHome"] = getUserHome(connectionData["userPrincipalShort"]!)
            } catch {
                connectionData["userHome"] = ""
            }
            
            do {
             try setDisplayName(connectionData["userPrincipalShort"]!)
            } catch {
                
            }
            
            defaults.setObject(connectionData["userHome"], forKey: "userHome")
            
            NSLog("User info found")
        }
        
        defaults.setObject(connectionData["userPrincipal"], forKey: "userPrincipal")
        
        let userinfo = UserInfo(connectionTestURL:  connectionData["connectionTestURL"]!,
                                connectionTestResult: connectionData["connectionTestResult"]!,
                                realm: connectionData["realm"]!,
                                domain: connectionData["domain"]!,
                                ldapServer: connectionData["ldapServer"]!,
                                ldapServerNamingContext: connectionData["ldapServerNamingContext"]!,
                                serverPasswordExpireDefaults: serverPasswordExpirationDefault,
                                passwordAging: connectionFlags["passwordAging"]!,
                                isConnected: connectionFlags["isConnected"]!,
                                isLoggedIn: connectionFlags["isLoggedIn"]!,
                                status: connectionData["status"]!,
                                userShortName: getConsoleUser(),
                                userLongName: NSUserName(),
                                userPrincipal: connectionData["userPrincipal"]!,
                                userPrincipalShort: connectionData["userPrincipalShort"]!,
                                userPasswordSetDate: connectionDates["userPasswordSetDate"]!,
                                userPasswordExpireDate: connectionDates["userPasswordExpireDate"]!,
                                userHome: connectionData["userHome"]!,
                                userCertDate: NSDate(),
                                userTicketExpireTime: connectionDates["userTicketExpireTime"]!)
        
        // Log where we are
        
        if defaults.integerForKey("Verbose") >= 2 {
            NSLog("User information state:")
            NSLog("Connection test URL: " + userinfo.connectionTestURL)
            NSLog("Connection test result: " + userinfo.connectionTestResult)
            NSLog("Realm: " + userinfo.realm)
            NSLog("Domain: " + userinfo.domain)
            NSLog("LDAP Server: " + userinfo.ldapServer)
            NSLog("LDAP Server Naming Context: " + userinfo.ldapServerNamingContext)
            NSLog("Password expiration default: " + String(serverPasswordExpirationDefault))
            NSLog("Password aging: " + String(userinfo.passwordAging))
            NSLog("Connected: " + String(userinfo.isConnected))
            NSLog("Logged in: " + String(userinfo.isLoggedIn))
            NSLog("Status: " + userinfo.status)
            NSLog("User short name: " + userinfo.userShortName)
            NSLog("User long name: " + userinfo.userLongName)
            NSLog("User principal: " + userinfo.userPrincipal)
            NSLog("TGT expires: " + String(userinfo.userTicketExpireTime))
            NSLog("User password set date: " + String(userinfo.userPasswordSetDate))
            NSLog("User password expire date: " + String(userinfo.userPasswordExpireDate))
            NSLog("User home share: " + userinfo.userHome)
        }
        
        return userinfo
    }
    
    // this lets us know if we're on the network
    
    func ConnectionStatus ( connectionTestURL: String, connectionTestResult: String )  throws {
        
        // lookup connectionTestURL to see if we can get it
        
        if (connectionTestURL == "") {
            // use dig to test for SRV records 
            var dnsResults = cliTask("/usr/bin/dig +short +time=2 -t SRV _ldap._tcp." + connectionData["domain"]!).componentsSeparatedByString("\n")
            
            // check to make sure we got a result
            
            if dnsResults[0] == "" || dnsResults[0].containsString("connection timed out") {
            throw NoADError.NotConnected
            }
        } else if connectionTestURL == "" {
        
        let lookupResult = cliTask("dig +short " + connectionTestURL )
        
        if lookupResult == "" {
            throw NoADError.NotConnected
        }
            } else {
                let lookupResult = cliTask("dig +short " + connectionTestURL )
                guard (lookupResult.rangeOfString(connectionTestResult) != nil)   else {
                    throw NoADError.NotConnected
            }
        }
        
        connectionFlags["isConnected"] = true
        connectionData["status"] = "Connected"
        
        // Log where we are
        
        if defaults.integerForKey("Verbose") >= 1 {
            NSLog("Finished testing connection.")
        }
    }
    
    // this checks to see if we're logged in and then gets the current principal
    
    func TGTPrincpalName ( realm : String ) throws {
        
        // parses klist to get a user name for the specified realm
        
        myTickets.getDetails()
        
        let fullTGT = cliTask("/usr/bin/klist -l")
        guard (fullTGT.rangeOfString(realm) != nil) else {
            throw NoADError.NotLoggedIn
        }
        
        // now find the active user line from klist
        
        let lines = fullTGT.componentsSeparatedByString("\n")
        
        for line in lines {
            if line.characters.first == "*" {
                connectionData["userPrincipal"] = line.componentsSeparatedByCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())[1]
                
                // we're getting stuck here if an ticket is expired, we'll never show the user name again
                // TODO: fix this
                
                if line.rangeOfString("Expired") != nil {
                    connectionData["status"] = "Expired Login"
                    connectionData["userPrincipalShort"] = (connectionData["userPrincipal"]!).stringByReplacingOccurrencesOfString("@" + connectionData["realm"]!, withString: "").stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
                    connectionFlags["isLoggedIn"] = false as Bool
                    //connectionFlags["isLoggedIn"] = false
                    connectionData["userPrincipal"] = "No User"
                    connectionData["userPrincipalShort"] = "No User"
                    connectionData["ldapServer"] = ""
                    connectionData["ldapServerNamingContext"] = ""
                    connectionDates["userPasswordSetDate"] = NSDate()
                    connectionDates["userPasswordExpireDate"] = NSDate()
                    serverPasswordExpirationDefault = NSTimeInterval()
                    connectionData["userHome"] = ""
                    connectionFlags["passwordAging"] = false
                    connectionDates["userTicketExpireTime"] = NSDate()
                    break
                } else {
                    connectionFlags["isLoggedIn"] = true as Bool
                    //  connectionData["userPrincipal"] = fullTGT.componentsSeparatedByString(" ")[11]
                    connectionData["userPrincipalShort"] = (connectionData["userPrincipal"]!).stringByReplacingOccurrencesOfString("@" + connectionData["realm"]!, withString: "").stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
                    defaults.setObject(connectionData["userPrincipalShort"], forKey: "LastUser")
                    connectionData["status"] = "Logged In"
                    connectionDates["userTicketExpireTime"] = getTicketTime()
                    break
                }
            }
        }
        
        // Log where we are
        
        if defaults.integerForKey("Verbose") >= 1 {
            NSLog("Logged in as user: " + connectionData["userPrincipal"]!)
            NSLog("Status: " + connectionData["status"]!)
        }
        
    }
    
    // this gets LDAP information from the server
    
    func getLDAPInfo ( domain: String ) throws {
        
        connectionData["ldapServer"] = myLDAPServers.currentServer
        defaults.setObject(myLDAPServers.currentServer, forKey: "CurrentLDAPServer")
        connectionData["ldapServerNamingContext"] = myLDAPServers.defaultNamingContext
        let passwordSetDate = try myLDAPServers.getLDAPInformation("pwdLastSet", searchTerm: "sAMAccountName=" + connectionData["userPrincipalShort"]!)
        connectionDates["userPasswordSetDate"] = NSDate(timeIntervalSince1970: (Double(Int(passwordSetDate)!))/10000000-11644473600)
        
        // Now get default password expiration time - this may not be set for environments with no password cycling requirements
        
        if myLDAPServers.currentState {
            NSLog("Getting password aging info")
            
            guard ( passwordSetDate != "" ) else {
                throw NoADError.UserPasswordSetDate
            }
            
            // First try msDS-UserPasswordExpiryTimeComputed
            
            let computedExpireDateRaw = try myLDAPServers.getLDAPInformation("msDS-UserPasswordExpiryTimeComputed", searchTerm: "sAMAccountName=" + connectionData["userPrincipalShort"]!)
            
            if ( Int(computedExpireDateRaw) == 9223372036854775807 ) {
                
                // password doesn't expire
                
                connectionFlags["passwordAging"] = false
                defaults.setObject(false, forKey: "UserAging")
                
                // set expiration to set date
                
                connectionDates["userPasswordExpireDate"] = connectionDates["userPasswordSetDate"]
                
            } else if ( Int(computedExpireDateRaw) != nil ) {
                
                // password expires
                
                connectionFlags["passwordAging"] = true
                defaults.setObject(true, forKey: "UserAging")
                let computedExpireDate = NSDate(timeIntervalSince1970: (Double(Int(computedExpireDateRaw)!))/10000000-11644473600)
                connectionDates["userPasswordExpireDate"] = computedExpireDate

            } else {
                
                // need to go old skool
                
                let passwordExpirationLength = try myLDAPServers.getLDAPInformation("maxPwdAge", baseSearch: true )
                
                if ( passwordExpirationLength.characters.count > 15 ) {
                    serverPasswordExpirationDefault = Double(0)
                    connectionFlags["passwordAging"] = false
                } else if ( passwordExpirationLength != "" ){
                    
                    // now check the users uAC to see if they are exempt
                    
                    let userPasswordUACFlag = try myLDAPServers.getLDAPInformation("userAccountControl", searchTerm: "sAMAccountName=" + connectionData["userPrincipalShort"]!)
                    
                    if ~~( Int(userPasswordUACFlag)! & 0x10000 ) {
                        connectionFlags["passwordAging"] = false
                        defaults.setObject(false, forKey: "UserAging")
                        } else {
                        serverPasswordExpirationDefault = Double(abs(Int(passwordExpirationLength)!)/10000000)
                        connectionFlags["passwordAging"] = true
                        defaults.setObject(true, forKey: "UserAging")
                    }
                } else {
                    serverPasswordExpirationDefault = Double(0)
                    connectionFlags["passwordAging"] = false
                }
                
                connectionDates["userPasswordExpireDate"] = connectionDates["userPasswordSetDate"]?.dateByAddingTimeInterval(serverPasswordExpirationDefault)

            }
            
            let lastDate = defaults.objectForKey("userPasswordSetDate") ?? nil
            
            defaults.setObject(connectionDates["userPasswordExpireDate"], forKey: "LastPasswordExpireDate")
            
            defaults.setObject(connectionDates["userPasswordExpireDate"], forKey: "LastPasswordExpireDate")
            
            // end new stuff
            
            if ( lastDate != nil && connectionDates["userPasswordSetDate"] != lastDate as! NSDate ) {
                NSLog("-----password changed underneath us----")
                //let myAlert = NSAlert()
            //myAlert.messageText = "Your network password has changed. Please login again."
                //myAlert.runModal()
            }
            defaults.setObject(connectionDates["userPasswordExpireDate"], forKey: "LastPasswordExpireDate")
            defaults.setObject(connectionDates["userPasswordSetDate"], forKey: "userPasswordSetDate")
        } else {
            throw NoADError.LDAPServerLookup
        }
        
    }
    
    // utility functions
    
    // get the users home attribute
    
    func getUserHome(userShortName: String) throws -> String {
        
        if myLDAPServers.currentState {
            let userHome = try myLDAPServers.getLDAPInformation("homeDirectory", searchTerm: "sAMAccountName=" + connectionData["userPrincipalShort"]!)
            
            guard ( userHome != "" ) else {
                throw NoADError.UserHome
            }
            
            return userHome.stringByReplacingOccurrencesOfString("\\", withString: "/")
        } else {
            throw NoADError.LDAPServerLookup
        }
        
    }
    
    // this finds the user's display name
    
    func setDisplayName (userShortName: String) throws {
        
        if myLDAPServers.currentState {
        let displayName = try myLDAPServers.getLDAPInformation("displayName", searchTerm: "sAMAccountName=" + connectionData["userPrincipalShort"]!)
        
            guard ( displayName != "" ) else {
                throw NoADError.LDAPServerLookup
            }
            
        defaults.setObject(displayName, forKey: "displayName")
        
        } else {
            throw NoADError.LDAPServerLookup
        }
    }
    
    // parses the local TGT and gets the ticket expiration time
    
    func getTicketTime() -> NSDate {
        let myTickettime = cliTaskNoTerm("/usr/bin/klist -v").componentsSeparatedByString("\n")
        var expireTimeEnglish: String = ""
        
        for line in myTickettime {
            if line.containsString("End time:") {
                expireTimeEnglish = line.stringByReplacingOccurrencesOfString("End time:", withString: "").stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
            }
        }
        
        let myDateFormatter = NSDateFormatter()
        myDateFormatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
        myDateFormatter.dateFormat = "MMMM dd HH:mm:ss yyyy"
        
        return myDateFormatter.dateFromString(expireTimeEnglish)!
    }
    
    // simple function to renew tickets
    
    func renewTickets(){
        cliTask("/usr/bin/kinit -R")
        if defaults.integerForKey("Verbose") >= 1 {
            NSLog("Renewing tickets.")
        }
    }
    
    //end of class
}
