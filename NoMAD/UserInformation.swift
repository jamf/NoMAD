//
//  UserInformation.swift
//  NoMAD
//
//  Created by Joel Rennich on 8/20/16.
//  Copyright © 2016 Orchard & Grove Inc. All rights reserved.
//

import Foundation

class UserInformation {

    // set up defaults for the domain

    var status = "NoMADMenuController-NotConnected"
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

    var userEmail: String
    var UPN: String
    var dn: String

    // Password last set info

    var lastSetDate = NSDate()

    var userCertDate = NSDate()
    var groups = [String]()

    let myLDAPServers = LDAPServers()
    let myKeychainUtil = KeychainUtil()

    var UserPasswordSetDates = [String : AnyObject ]()
    
    // timer information
    
    var myTimer: Timer?
    var timerDate: Date?

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
        userEmail = ""
        UPN = ""
        dn = ""
        if defaults.dictionary(forKey: Preferences.userPasswordSetDates) != nil {
            UserPasswordSetDates = defaults.dictionary(forKey: Preferences.userPasswordSetDates)! as [String : AnyObject]
        }
    }

    func checkNetwork() -> Bool {
        myLDAPServers.check()
        return myLDAPServers.returnState()
    }

    // Determine what certs are available locally

    func getCertDate() {
        guard let myCertExpire = myKeychainUtil.findCertExpiration(UPN, defaultNamingContext: myLDAPServers.defaultNamingContext) else {
            myLogger.logit(.base, message: "Could not retrive certificate.")
            defaults.set("", forKey: Preferences.lastCertificateExpiration)
            return
        }

        if myCertExpire > Date().addingTimeInterval(2592000) {
            myLogger.logit(.info, message: "Last certificate will expire on: " + String(describing: myCertExpire))
        }

        if myCertExpire.timeIntervalSinceNow < 0  {
            myLogger.logit(.base, message: "Your certificate has already expired.")
        }

        // Act on Cert expiration
        if myCertExpire.timeIntervalSinceNow < 2592000 && myCertExpire.timeIntervalSinceNow > 0 {
            myLogger.logit(.base, message: "Your certificate will expire in less than 30 days.")

            // TODO: Trigger an action

        }

        defaults.set(myCertExpire, forKey: Preferences.lastCertificateExpiration)
    }

    func getUserInfo() {

        // 1. check if AD can be reached

        var canary = true
        checkNetwork()

        //myLDAPServers.tickets.getDetails()

        if myLDAPServers.currentState {
            status = "NoMADMenuController-Connected"
            connected = true
        } else {
            status = "NoMADMenuController-NotConnected"
            connected = false
            myLogger.logit(.base, message: "Not connected to the network")
        }

        // 2. check for tickets

        if myLDAPServers.tickets.state {
            userPrincipal = myLDAPServers.tickets.returnDefaultPrincipal()
            realm = defaults.string(forKey: Preferences.kerberosRealm)!
            if userPrincipal.contains(realm) {
                userPrincipalShort = userPrincipal.replacingOccurrences(of: "@" + realm, with: "")
                status = "Logged In"
                myLogger.logit(.base, message: "Logged in.")
            } else {
                myLogger.logit(.base, message: "No ticket for realm.")
            }
        } else {
            myLogger.logit(.base, message: "No tickets")
        }

        // 3. if connected and with tickets, get password aging information
        
        
        var passwordSetDate: String?
        var computedExpireDateRaw: String?
        var userPasswordUACFlag: String = ""
        var userHomeTemp: String = ""
        //var userDisplayNameTemp: String = ""
        //var userDisplayName: String = ""
        var groupsTemp: String?

        if connected && myLDAPServers.tickets.state {

            if !defaults.bool(forKey: Preferences.lDAPOnly) {

            let attributes = ["pwdLastSet", "msDS-UserPasswordExpiryTimeComputed", "userAccountControl", "homeDirectory", "displayName", "memberOf", "mail", "userPrincipalName", "dn"] // passwordSetDate, computedExpireDateRaw, userPasswordUACFlag, userHomeTemp, userDisplayName, groupTemp
            // "maxPwdAge" // passwordExpirationLength

            let searchTerm = "sAMAccountName=" + userPrincipalShort

            if let ldifResult = try? myLDAPServers.getLDAPInformation(attributes, searchTerm: searchTerm) {
                let ldapResult = myLDAPServers.getAttributesForSingleRecordFromCleanedLDIF(attributes, ldif: ldifResult)
                passwordSetDate = ldapResult["pwdLastSet"]
                computedExpireDateRaw = ldapResult["msDS-UserPasswordExpiryTimeComputed"]
                userPasswordUACFlag = ldapResult["userAccountControl"] ?? ""
                userHomeTemp = ldapResult["homeDirectory"] ?? ""
                userDisplayName = ldapResult["displayName"] ?? ""
                groupsTemp = ldapResult["memberOf"]
                userEmail = ldapResult["mail"] ?? ""
                UPN = ldapResult["userPrincipalName"] ?? ""
                dn = ldapResult["dn"] ?? ""
            } else {
                myLogger.logit(.base, message: "Unable to find user.")
                canary = false
            }
            
            // check if we are overriding the password expiration date
            
            if ( defaults.object(forKey: Preferences.passwordExpirationDays) ?? nil ) != nil {
                passwordSetDate = nil
            }
                
                // now to get recursive groups if asked
                
                if defaults.bool(forKey: Preferences.recursiveGroupLookup) {
                    let attributes = ["name"]
                     let searchTerm = "(member:1.2.840.113556.1.4.1941:=" + dn.replacingOccurrences(of: "\\", with: "\\\\5c") + ")"
                    if let ldifResult = try? myLDAPServers.getLDAPInformation(attributes, searchTerm: searchTerm) {                        
                        groupsTemp = ""
                        for item in ldifResult {
                            for components in item {
                                if components.key == "dn" {
                                    groupsTemp?.append(components.value + ";")
                                }
                            }
                        }
                    }
                }
            
            if canary {
                if (passwordSetDate != nil) {
                    userPasswordSetDate = NSDate(timeIntervalSince1970: (Double(passwordSetDate!)!)/10000000-11644473600)
                }
                if ( computedExpireDateRaw != nil) {
                    // Windows Server 2008 and Newer
                    if ( Int(computedExpireDateRaw!) == 9223372036854775807) || defaults.bool(forKey: Preferences.hideExpiration) {
                        // Password doesn't expire
                        passwordAging = false
                        defaults.set(false, forKey: Preferences.userAging)

                        // Set expiration to set date
                        userPasswordExpireDate = NSDate()
                    } else if (Int(computedExpireDateRaw!) == 0) {
                        // password needs to be reset
                        passwordAging = true
                        defaults.set(true, forKey: Preferences.userAging)

                        // TODO: Change all Double() to NumberFormatter().number(from: myString)?.doubleValue
                        //       when we switch to Swift 3
                        let computedExpireDate = NSDate()

                        // Set expiration to the computed date.
                        userPasswordExpireDate = computedExpireDate

                    } else {
                        // Password expires

                        passwordAging = true
                        defaults.set(true, forKey: Preferences.userAging)

                        // TODO: Change all Double() to NumberFormatter().number(from: myString)?.doubleValue
                        //       when we switch to Swift 3
                        let computedExpireDate = NSDate(timeIntervalSince1970: (Double(computedExpireDateRaw!)!)/10000000-11644473600)

                        // Set expiration to the computed date.
                        userPasswordExpireDate = computedExpireDate
                    }
                } else {
                    // Older then Windows Server 2008
                    // need to go old skool
                    var passwordExpirationLength: String
                    let attribute = "maxPwdAge"
                    
                    if defaults.integer(forKey: Preferences.passwordExpirationDays) != nil {
                        passwordExpirationLength = String(describing: defaults.integer(forKey: Preferences.passwordExpirationDays))
                    } else {

                    if let ldifResult = try? myLDAPServers.getLDAPInformation([attribute], baseSearch: true) {
                        passwordExpirationLength = myLDAPServers.getAttributeForSingleRecordFromCleanedLDIF(attribute, ldif: ldifResult)
                    } else {
                        passwordExpirationLength = ""
                    }
                }

                    if ( passwordExpirationLength.characters.count > 15 ) {
                        passwordAging = false
                    } else if ( passwordExpirationLength != "" ) && userPasswordUACFlag != "" {
                        if ~~( Int(userPasswordUACFlag)! & 0x10000 ) {
                            passwordAging = false
                            defaults.set(false, forKey: Preferences.userAging)
                        } else {
                            serverPasswordExpirationDefault = Double(abs(Int(passwordExpirationLength)!)/10000000)
                            passwordAging = true
                            defaults.set(true, forKey: Preferences.userAging)
                        }
                    } else {
                        serverPasswordExpirationDefault = Double(0)
                        passwordAging = false
                    }
                    userPasswordExpireDate = userPasswordSetDate.addingTimeInterval(serverPasswordExpirationDefault)
                }

            }
            } else {

                let attributes = [ "homeDirectory", "displayName", "memberOf", "mail", "uid"] // passwordSetDate, computedExpireDateRaw, userPasswordUACFlag, userHomeTemp, userDisplayName, groupTemp
                // "maxPwdAge" // passwordExpirationLength

                let searchTerm = "uid=" + userPrincipalShort

                if let ldifResult = try? myLDAPServers.getLDAPInformation(attributes, searchTerm: searchTerm) {
                    let ldapResult = myLDAPServers.getAttributesForSingleRecordFromCleanedLDIF(attributes, ldif: ldifResult)
                    userHomeTemp = ldapResult["homeDirectory"] ?? ""
                    userDisplayName = ldapResult["displayName"] ?? ""
                    groupsTemp = ldapResult["memberOf"]
                    userEmail = ldapResult["mail"] ?? ""
                    UPN = ldapResult["uid"] ?? ""
                } else {
                    myLogger.logit(.base, message: "Unable to find user.")
                    canary = false
                    
                }

                // groupOfNames would go here

                passwordAging = false

            }

            // Check if the password was changed without NoMAD knowing.
            myLogger.logit(LogLevel.debug, message: "Password set: " + String(describing: UserPasswordSetDates[userPrincipal]))
            if (UserPasswordSetDates[userPrincipal] != nil) && ( (UserPasswordSetDates[userPrincipal] as? String) != "just set" ) {
                // user has been previously set so we can check it

                if let passLastChangeDate = (UserPasswordSetDates[userPrincipal] as? Date ) {
                    if ((userPasswordSetDate.timeIntervalSince(passLastChangeDate as Date)) > 1 * 60 ){

                    myLogger.logit(.base, message: "Password was changed underneath us.")
                        
                        // if we are using a web method to change the password we should update more often
                        
                        if defaults.string(forKey: Preferences.changePasswordType) == "URL" {
                            
                            timerDate = Date()
                            
                            myTimer = Timer.init(timeInterval: 30, target: self, selector: #selector(postUpdate), userInfo: nil, repeats: true)
                            RunLoop.main.add(myTimer!, forMode: .commonModes)
                        }
                        
                    if (defaults.string(forKey: Preferences.uPCAlertAction) != nil ) && (defaults.string(forKey: Preferences.uPCAlertAction) != "" ) {
                        myLogger.logit(.base, message: "Firing UPC Alert Action")
                        cliTask(defaults.string(forKey: Preferences.uPCAlertAction)! + " &")
                    }

                    // record the new password set date

                    UserPasswordSetDates[userPrincipal] = userPasswordSetDate
                    defaults.set(UserPasswordSetDates, forKey: Preferences.userPasswordSetDates)
                    
                    // set a flag it we should alert the user
                    if (defaults.bool(forKey: Preferences.uPCAlert ) == true) {

                        // fire the notification

                        myLogger.logit(.base, message: "Alerting user to UPC.")

                        let notification = NSUserNotification()
                        notification.title = "UserInformation-PasswordChanged".translate
                        notification.informativeText = defaults.string(forKey: Preferences.messageUPCAlert) ?? "UserInformation-PwdChangedSignInAgain".translate
                        //notification.deliveryDate = date
                        notification.hasActionButton = true
                        notification.actionButtonTitle = "SignIn".translate
                        notification.otherButtonTitle = "UserInformation-Ignore".translate
                        notification.soundName = NSUserNotificationDefaultSoundName
                        NSUserNotificationCenter.default.deliver(notification)

                        //NotificationQueue.default.enqueue(updateNotification, postingStyle: .now)
                    }
                }
            } else {
                UserPasswordSetDates[userPrincipal] = userPasswordSetDate
                defaults.set(UserPasswordSetDates, forKey: Preferences.userPasswordSetDates)
            }
            } else {
                // write out the password dates

                UserPasswordSetDates[userPrincipal] = userPasswordSetDate
                defaults.set(UserPasswordSetDates, forKey: Preferences.userPasswordSetDates)
            }
        } else if defaults.bool(forKey: Preferences.persistExpiration) {

            // we can't connect, so just use the last stashed information
            // first we check to make sure someone has logged in before

            if  let userPrincipal = defaults.string(forKey: Preferences.userPrincipal) {

                if userPrincipal != "" {
                self.userPrincipal = userPrincipal
            self.passwordAging = defaults.bool(forKey: Preferences.userAging)
            self.userPasswordExpireDate = defaults.object(forKey: Preferences.lastPasswordExpireDate) as! NSDate
                self.realm = defaults.string(forKey: Preferences.kerberosRealm)!
                self.userDisplayName = defaults.string(forKey: Preferences.displayName)!
                self.userShortName = defaults.string(forKey: Preferences.lastUser)!
                self.userPrincipalShort = defaults.string(forKey: Preferences.lastUser)!
                }
            }
        }

        // 4. if connected and with tickets, get all of user information
        if connected && myLDAPServers.tickets.state && canary {
            userHome = userHomeTemp.replacingOccurrences(of: "\\", with: "/")

            groups.removeAll()

            if groupsTemp != nil {
                let groupsArray = groupsTemp!.components(separatedBy: ";")
                for group in groupsArray {
                    let a = group.components(separatedBy: ",")
                    var b = a[0].replacingOccurrences(of: "CN=", with: "") as String
                    b = b.replacingOccurrences(of: "cn=", with: "") as String

                    if b != "" {
                        groups.append(b)
                    }
                }
                myLogger.logit(.info, message: "You are a member of: " + groups.joined(separator: ", ") )
            }

            // look at local certs if an x509 CA has been set

            if (defaults.string(forKey: Preferences.x509CA) ?? "" != "") {
                getCertDate()
            }

            userHome = userHome.replacingOccurrences(of: " ", with: "%20")

            defaults.set(userHome, forKey: Preferences.userHome)
            defaults.set(userDisplayName, forKey: Preferences.displayName)
            defaults.set(userPrincipal, forKey: Preferences.userPrincipal)
            defaults.set(userPrincipalShort, forKey: Preferences.lastUser)
            defaults.set(userPasswordExpireDate, forKey: Preferences.lastPasswordExpireDate)
            defaults.set(groups, forKey: Preferences.groups)
            defaults.set(UPN, forKey: Preferences.userUPN)
            defaults.set(userEmail, forKey: Preferences.userEmail)
        }
    }
    
    // for timer - post update
    
    @objc func postUpdate() {
        NotificationQueue.default.enqueue(updateNotification, postingStyle: .now)
        
        if (timerDate?.timeIntervalSinceNow)! < ( 0 - ( 15 * 60 )) {
            myTimer?.invalidate()
        }
    }
}
