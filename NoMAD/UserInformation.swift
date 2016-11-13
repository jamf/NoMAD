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
        if defaults.dictionary(forKey: "UserPasswordSetDates") != nil {
            UserPasswordSetDates = defaults.dictionary(forKey: "UserPasswordSetDates")! as [String : AnyObject]
        }
    }

    func checkNetwork() -> Bool {
        myLDAPServers.check()
        return myLDAPServers.returnState()
    }

    // Determine what certs are available locally

    func getCertDate() {
        guard let myCertExpire = myKeychainUtil.findCertExpiration(userEmail, defaultNamingContext: myLDAPServers.defaultNamingContext) else {
            myLogger.logit(.base, message: "Could not retrive certificate")
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

            let attributes = ["pwdLastSet", "msDS-UserPasswordExpiryTimeComputed", "userAccountControl", "homeDirectory", "displayName", "memberOf", "mail"] // passwordSetDate, computedExpireDateRaw, userPasswordUACFlag, userHomeTemp, userDisplayName, groupTemp
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
            myLogger.logit(LogLevel.debug, message: String(describing: UserPasswordSetDates[userPrincipal]))
            if (UserPasswordSetDates[userPrincipal] != nil) && ( (UserPasswordSetDates[userPrincipal] as? String) != "just set" ) {
                // user has been previously set so we can check it

                if ((UserPasswordSetDates[userPrincipal] as? NSDate ) != userPasswordSetDate) {
                    myLogger.logit(.base, message: "Password was changed underneath us.")

                    // TODO: Do something if we get here

                    let alertController = NSAlert()
                    alertController.messageText = "Your Password Changed"
                    alertController.runModal()

                    // record the new password set date

                    UserPasswordSetDates[userPrincipal] = userPasswordSetDate
                    defaults.set(UserPasswordSetDates, forKey: "UserPasswordSetDates")

                }
            } else {
                UserPasswordSetDates[userPrincipal] = userPasswordSetDate
                defaults.set(UserPasswordSetDates, forKey: "UserPasswordSetDates")
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

            defaults.set(userHome, forKey: "userHome")
            defaults.set(userDisplayName, forKey: "displayName")
            defaults.set(userPrincipal, forKey: "userPrincipal")
            defaults.set(userPrincipalShort, forKey: Preferences.lastUser)
            defaults.set(userPasswordExpireDate, forKey: "LastPasswordExpireDate")
            defaults.set(groups, forKey: "Groups")
        }
    }

    /*
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
     realm = defaults.stringForKey("KerberosRealm")!
     if userPrincipal.containsString(realm) {
     userPrincipalShort = userPrincipal.stringByReplacingOccurrencesOfString("@" + realm, withString: "")
     status = "Logged In"
     myLogger.logit(.base, message: "Logged in.")
     } else {
     myLogger.logit(.base, message: "No ticket for realm.")
     }
     } else {
     myLogger.logit(.base, message: "No tickets")
     }

     // 3. if connected and with tickets, get password aging information

     if connected && myLDAPServers.tickets.state {

     var passwordSetDate = ""
     let attributes = ["pwdLastSet", "msDS-UserPasswordExpiryTimeComputed", "userAccountControl", "homeDirectory", "displayName", "memberOf"]

     let attribute = "pwdLastSet"
     let searchTerm = "sAMAccountName=" + userPrincipalShort

     guard let ldifResult = try? myLDAPServers.getLDAPInformation([attribute], searchTerm: searchTerm) else {
     passwordSetDate = ""
     myLogger.logit(.base, message: "We shouldn't have gotten here... tell Joel")
     canary = false
     }
     passwordSetDate = myLDAPServers.getAttributeForSingleRecordFromCleanedLDIF(attribute, ldif: ldifResult)

     if canary {
     if (passwordSetDate != "") {
					userPasswordSetDate = NSDate(timeIntervalSince1970: (Double(Int(passwordSetDate)!))/10000000-11644473600)
     }

     // Now get default password expiration time - this may not be set for environments with no password cycling requirements

     myLogger.logit(.info, message: "Getting password aging info")

     // First try msDS-UserPasswordExpiryTimeComputed
     var computedExpireDateRaw: String
     let attribute = "msDS-UserPasswordExpiryTimeComputed"
     let searchTerm = "sAMAccountName=" + userPrincipalShort
     if let ldifResult = try? myLDAPServers.getLDAPInformation([attribute], searchTerm: searchTerm) {
					computedExpireDateRaw = myLDAPServers.getAttributeForSingleRecordFromCleanedLDIF(attribute, ldif: ldifResult)
     } else {
					computedExpireDateRaw = ""
     }


     if ( Int(computedExpireDateRaw) == 9223372036854775807 ) {

     // password doesn't expire

     passwordAging = false
     defaults.setObject(false, forKey: Preferences.userAging)

     // set expiration to set date

     userPasswordExpireDate = NSDate()

     } else if ( Int(computedExpireDateRaw) != nil ) {

     // password expires

     passwordAging = true
     defaults.setObject(true, forKey: Preferences.userAging)
     let computedExpireDate = NSDate(timeIntervalSince1970: (Double(Int(computedExpireDateRaw)!))/10000000-11644473600)
     userPasswordExpireDate = computedExpireDate

     } else {

     // need to go old skool
					var passwordExpirationLength: String
					let attribute = "maxPwdAge"

					if let ldifResult = try? myLDAPServers.getLDAPInformation([attribute], baseSearch: true) {
     passwordExpirationLength = myLDAPServers.getAttributeForSingleRecordFromCleanedLDIF(attribute, ldif: ldifResult)
					} else {
     passwordExpirationLength = ""
					}
     //let passwordExpirationLength = try! myLDAPServers.getLDAPInformation("maxPwdAge", baseSearch: true )

     if ( passwordExpirationLength.characters.count > 15 ) {
     //serverPasswordExpirationDefault = Double(0)
     passwordAging = false
     } else if ( passwordExpirationLength != "" ){

     // now check the users uAC to see if they are exempt
     var userPasswordUACFlag: String
     let attribute = "userAccountControl"
     let searchTerm = "sAMAccountName=" + userPrincipalShort

     if let ldifResult = try? myLDAPServers.getLDAPInformation([attribute], searchTerm: searchTerm) {
     userPasswordUACFlag = myLDAPServers.getAttributeForSingleRecordFromCleanedLDIF(attribute, ldif: ldifResult)
     } else {
     userPasswordUACFlag = ""
     }

     if ~~( Int(userPasswordUACFlag)! & 0x10000 ) {
     passwordAging = false
     defaults.setObject(false, forKey: Preferences.userAging)
     } else {
     serverPasswordExpirationDefault = Double(abs(Int(passwordExpirationLength)!)/10000000)
     passwordAging = true
     defaults.setObject(true, forKey: Preferences.userAging)
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
					myLogger.logit(.base, message: "Password was changed underneath us.")

					// TODO: Do something if we get here

     let alertController = NSAlert()
     alertController.messageText = "Your Password Changed"
     alertController.runModal()

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

     myLogger.logit(.info, message: "You are a member of: " + groups.joinWithSeparator(", ") )

     // look at local certs if an x509 CA has been set

     if (defaults.stringForKey("x509CA") ?? "" != "") {

     let myCertExpire = myKeychainUtil.findCertExpiration(userDisplayName, defaultNamingContext: myLDAPServers.defaultNamingContext )

     if myCertExpire != 0 {
     myLogger.logit(.info, message: "Last certificate will expire on: " + String(myCertExpire) )
     }

     // Act on Cert expiration

     if myCertExpire.timeIntervalSinceNow < 2592000 && myCertExpire.timeIntervalSinceNow > 0 {
     myLogger.logit(.base, message: "Your certificate will expire in less than 30 days.")

     // TODO: Trigger an action

     }

     if myCertExpire.timeIntervalSinceNow < 0 && myCertExpire != NSDate.distantPast() {
     myLogger.logit(.base, message: "Your certificate has already expired.")
     }

     defaults.setObject(myCertExpire, forKey: Preferences.lastCertificateExpiration)

     }


     // set defaults for these

     defaults.setObject(userHome, forKey: "userHome")
     defaults.setObject(userDisplayName, forKey: "displayName")
     defaults.setObject(userPrincipal, forKey: "userPrincipal")
     defaults.setObject(userPrincipalShort, forKey: Preferences.lastUser)
     defaults.setObject(userPasswordExpireDate, forKey: "LastPasswordExpireDate")
     defaults.setObject(groups, forKey: "Groups")
     }
     
     myLogger.logit(.base, message: "User information update done.")
     }
     */
    
}
