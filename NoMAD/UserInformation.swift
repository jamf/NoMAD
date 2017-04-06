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

    // Password last set info

    var lastSetDate = NSDate()

    var userCertDate = NSDate()
    var groups = [String]()

    let myLDAPServers = LDAPServers()
    let myKeychainUtil = KeychainUtil()

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
        userEmail = ""
        UPN = ""
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
            userPrincipal = myLDAPServers.tickets.principal
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

            let attributes = ["pwdLastSet", "msDS-UserPasswordExpiryTimeComputed", "userAccountControl", "homeDirectory", "displayName", "memberOf", "mail", "userPrincipalName"] // passwordSetDate, computedExpireDateRaw, userPasswordUACFlag, userHomeTemp, userDisplayName, groupTemp
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
            } else {
                myLogger.logit(.base, message: "Unable to find user.")
                canary = false
            }
            if canary {
                if (passwordSetDate != nil) {
                    userPasswordSetDate = NSDate(timeIntervalSince1970: (Double(passwordSetDate!)!)/10000000-11644473600)
                }
                if ( computedExpireDateRaw != nil) {
                    // Windows Server 2008 and Newer
                    if ( Int(computedExpireDateRaw!) == 9223372036854775807) {
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
                    if let ldifResult = try? myLDAPServers.getLDAPInformation([attribute], baseSearch: true) {
                        passwordExpirationLength = myLDAPServers.getAttributeForSingleRecordFromCleanedLDIF(attribute, ldif: ldifResult)
                    } else {
                        passwordExpirationLength = ""
                    }

                    if ( passwordExpirationLength.characters.count > 15 ) {
                        passwordAging = false
                    } else if ( passwordExpirationLength != "" ) {
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
            // Check if the password was changed without NoMAD knowing.
            myLogger.logit(LogLevel.debug, message: "Password set: " + String(describing: UserPasswordSetDates[userPrincipal]))
            if (UserPasswordSetDates[userPrincipal] != nil) && ( (UserPasswordSetDates[userPrincipal] as? String) != "just set" ) {
                // user has been previously set so we can check it

                if let passLastChangeDate = (UserPasswordSetDates[userPrincipal] as? Date ) {
                    if ((userPasswordSetDate.timeIntervalSince(passLastChangeDate as Date)) > 1 * 60 ){

                    myLogger.logit(.base, message: "Password was changed underneath us.")
                        
                    if (defaults.bool(forKey: Preferences.uPCAlertLogout ) == true) {
                        cliTask("/usr/bin/kdestroy")
                    }

                    // record the new password set date

                    UserPasswordSetDates[userPrincipal] = userPasswordSetDate
                    defaults.set(UserPasswordSetDates, forKey: Preferences.userPasswordSetDates)
                    
                    // set a flag it we should alert the user
                    if (defaults.bool(forKey: Preferences.uPCAlert ) == true) {

                        // fire the notification

                        myLogger.logit(.base, message: "Alerting user to UPC.")

                        let notification = NSUserNotification()
                        notification.title = "Password Changed"
                        notification.informativeText = "Your password was changed, please re-sign into NoMAD to update your password."
                        //notification.deliveryDate = date
                        notification.hasActionButton = true
                        notification.actionButtonTitle = "NoMADMenuController-LogIn".translate
                        notification.otherButtonTitle = "Ignore"
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
        }

        // 4. if connected and with tickets, get all of user information
        if connected && myLDAPServers.tickets.state && canary {
            userHome = userHomeTemp.replacingOccurrences(of: "\\", with: "/")

            groups.removeAll()

            if groupsTemp != nil {
                let groupsArray = groupsTemp!.components(separatedBy: ";")
                for group in groupsArray {
                    let a = group.components(separatedBy: ",")
                    let b = a[0].replacingOccurrences(of: "CN=", with: "") as String
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

            defaults.set(userHome, forKey: Preferences.userHome)
            defaults.set(userDisplayName, forKey: Preferences.displayName)
            defaults.set(userPrincipal, forKey: Preferences.userPrincipal)
            defaults.set(userPrincipalShort, forKey: Preferences.lastUser)
            defaults.set(userPasswordExpireDate, forKey: Preferences.lastPasswordExpireDate)
            defaults.set(groups, forKey: Preferences.groups)
        }
    }
}
