//
//  KeychainUtil.swift
//  NoMAD
//
//  Created by Joel Rennich on 8/7/16.
//  Copyright © 2016 Trusource Labs. All rights reserved.
//

// class to manage all keychain interaction

import Foundation
import Security

struct certDates {
    var serial : String
    var expireDate : Date
}

class KeychainUtil {

    var myErr: OSStatus
    let serviceName = "NoMAD"
    var passLength: UInt32 = 0
    var passPtr: UnsafeMutableRawPointer? = nil

    var myKeychainItem: SecKeychainItem?

    init() {
        myErr = 0
    }

    // find if there is an existing account password and return it or throw

    func findPassword(_ name: String) throws -> String {

        myErr = SecKeychainFindGenericPassword(nil, UInt32(serviceName.characters.count), serviceName, UInt32(name.characters.count), name, &passLength, &passPtr, &myKeychainItem)

        if myErr == OSStatus(errSecSuccess) {
            let password = NSString(bytes: passPtr!, length: Int(passLength), encoding: String.Encoding.utf8.rawValue)
            return password as! String
        } else {
            throw NoADError.noStoredPassword
        }
    }

    // set the password

    func setPassword(_ name: String, pass: String) -> OSStatus {

        myErr = SecKeychainAddGenericPassword(nil, UInt32(serviceName.characters.count), serviceName, UInt32(name.characters.count), name, UInt32(pass.characters.count), pass, nil)

        return myErr
    }
    
    // update the password

    func updatePassword(_ name: String, pass: String) -> Bool {
        if (try? findPassword(name)) != nil {
            deletePassword()
        }
        myErr = setPassword(name, pass: pass)
        if myErr == OSStatus(errSecSuccess) {
            return true
        } else {
            myLogger.logit(LogLevel.base, message: "Unable to update keychain password.")
            return false
        }
    }

    // delete the password from the keychain

    func deletePassword() -> OSStatus {
        myErr = SecKeychainItemDelete(myKeychainItem!)
        return myErr
    }
    
    // check to see if the deafult Keychain is locked
    
    func checkLockedKeychain() -> Bool {
        
        var myKeychain: SecKeychain?
        var myKeychainStatus = SecKeychainStatus()
        
        // get the default keychain
        
        myErr = SecKeychainCopyDefault(&myKeychain)
        
        if myErr == OSStatus(errSecSuccess) {
            
            myErr = SecKeychainGetStatus(myKeychain, &myKeychainStatus)
            
            if Int(myKeychainStatus) == 2 {
                myLogger.logit(.debug, message: "Keychain is locked")
                return true
            }
            myLogger.logit(.debug, message: "Keychain is unlocked")
            return false
        } else {
            myLogger.logit(.debug, message: "Error checking to see if the Keychain is locked, assuming it is.")
            return true
        }
    }

    // convience functions

    func findAndDelete(_ name: String) -> Bool {
        do {
            try findPassword(name)
        } catch{
            return false
        }
        if ( deletePassword() == 0 ) {
            return true
        } else {
            return false
        }
    }

    // return the last expiration date for any certs that match the domain and user

    func findCertExpiration(_ identifier: String, defaultNamingContext: String) -> Date? {
        
        var lastExpire = Date.distantPast
        
        let certList = findAllUserCerts(identifier, defaultNamingContext: defaultNamingContext)
        
        for cert in certList! {
            if lastExpire.timeIntervalSinceNow < cert.expireDate.timeIntervalSinceNow {
                lastExpire = cert.expireDate
            }
        }
        return lastExpire
    }
    
    func findAllUserCerts(_ identifier: String, defaultNamingContext: String) -> [certDates]?{
        var matchingCerts = [certDates]()
        var myCert: SecCertificate? = nil
        var searchReturn: AnyObject? = nil
        
        // create a search dictionary to find Identitys with Private Keys and returning all matches
        
        /*
         @constant kSecMatchIssuers Specifies a dictionary key whose value is a
         CFArray of X.500 names (of type CFDataRef). If provided, returned
         certificates or identities will be limited to those whose
         certificate chain contains one of the issuers provided in this list.
         */
        
        // build our search dictionary
        
        let identitySearchDict: [String:AnyObject] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate as AnyObject,
            
            // this matches e-mail address
            //kSecMatchEmailAddressIfPresent as String : identifier as CFString,
            
            // this matches Common Name
            //kSecMatchSubjectContains as String : identifier as CFString,
            
            kSecReturnRef as String: true as AnyObject,
            kSecMatchLimit as String : kSecMatchLimitAll as AnyObject
        ]
        
        myErr = 0
        
        
        // look for all matches
        
        myErr = SecItemCopyMatching(identitySearchDict as CFDictionary, &searchReturn)
        
        if myErr != 0 {
            myLogger.logit(.base, message: "Error getting Certificates.")
            return nil
        }
        
        let foundCerts = searchReturn as! CFArray as Array
        
        if foundCerts.count == 0 {
            myLogger.logit(.info, message: "No certificates found.")
            return nil
        }
        
        for cert in foundCerts {
            
            myErr = SecIdentityCopyCertificate(cert as! SecIdentity, &myCert)
            
            if myErr != 0 {
                myLogger.logit(.base, message: "Error getting Certificate references.")
                return nil
            }
            
            // get the full OID set for the cert
            
            let myOIDs : NSDictionary = SecCertificateCopyValues(myCert!, nil, nil)!
            
            // look at the NT Principal name
            
            if myOIDs["2.5.29.17"] != nil {
                let SAN = myOIDs["2.5.29.17"] as! NSDictionary
                let SANValues = SAN["value"]! as! NSArray
                for values in SANValues {
                    let value = values as! NSDictionary
                    if String(_cocoaString: value["label"]! as AnyObject) == "1.3.6.1.4.1.311.20.2.3" {
                        if let myNTPrincipal = value["value"] {
                            // we have an NT Principal, let's see if it's Kerberos Principal we're looking for
                            myLogger.logit(.debug, message: "Certificate NT Principal: " + String(describing: myNTPrincipal) )
                            if String(describing: myNTPrincipal) == identifier {
                                myLogger.logit(.debug, message: "Found cert match")
                                
                                
                                // we have a match now gather the expire date and the serial
                                
                                let expireOID : NSDictionary = myOIDs["2.5.29.24"]! as! NSDictionary
                                let expireDate = expireOID["value"]! as! Date
                                
                                // this finds the serial
                                
                                let serialDict : NSDictionary = myOIDs["2.16.840.1.113741.2.1.1.1.3"]! as! NSDictionary
                                let serial = serialDict["value"]! as! String
                                
                                // pack the data up into a certDate
                                
                                let certificate = certDates( serial: serial, expireDate: expireDate)
                                
                                // append to the list
                                
                                matchingCerts.append(certificate)
                                
                            } else {
                                myLogger.logit(.debug, message: "Certificate doesn't match current user principal.")
                            }
                        }
                        
                    }
                }
            }
        }
        myLogger.logit(.debug, message: "Found " + String(matchingCerts.count) + " certificates.")
        myLogger.logit(.debug, message: "Found certificates: " + String(describing: matchingCerts) )
        
        return matchingCerts
    }

    func manageKeychainPasswords(newPassword: String) {
        // get the items to update
        
        myLogger.logit(.debug, message: "Attempting to update keychain items.")

        let myKeychainItems = defaults.dictionary(forKey: Preferences.keychainItems)
        
        // bail if there's nothing to update 

        if myKeychainItems?.count == 0 || myKeychainItems == nil {
            myLogger.logit(.debug, message: "No keychain items to update.")
            return
        }

        // set up the base search dictionary

        var itemSearch: [String:AnyObject] = [
            kSecClass as String: kSecClassGenericPassword as AnyObject,
            //kSecAttrAccount as String: defaults.string(forKey: Preferences.userUPN) as AnyObject,
            kSecMatchLimit as String : kSecMatchLimitAll as AnyObject
        ]
        
        // set up the new password dictionary

        let attrToUpdate: [String:AnyObject] = [
            kSecValueData as String: newPassword.data(using: .utf8) as AnyObject
        ]

        for item in myKeychainItems! {
            
            if defaults.bool(forKey: Preferences.keychainItemsDebug) {
                print(item)
            }

            // add in the Service name

            itemSearch[kSecAttrService as String] = item.key as AnyObject
            
            var aclUpdate = false
            var passLength: UInt32 = 0
            var passPtr: UnsafeMutableRawPointer? = nil
            var myKeychainItem: SecKeychainItem?
            var itemAccess: SecAccess? = nil
            var secApp: SecTrustedApplication? = nil
            var myACLs : CFArray? = nil

        
            // add in the swapped account name
            
            let account = (item.value as! String).variableSwap()
            
            if account != "" {
                itemSearch[kSecAttrAccount as String] = (item.value as! String).variableSwap() as AnyObject
            }
                
            if defaults.bool(forKey: Preferences.keychainItemsDebug) {
                print(itemSearch)
            }
            
            // now to loop through and find out if the item is available
            
            myErr = SecKeychainFindGenericPassword(nil, UInt32(item.key.characters.count), item.key, UInt32(account.characters.count), account, &passLength, &passPtr, &myKeychainItem)
            
            if myErr != 0 {
                myLogger.logit(.debug, message: "Adjusting ACL of keychain item \(item.key) : \(item.value).")
                aclUpdate = true
                myErr = SecKeychainItemCopyAccess(myKeychainItem!, &itemAccess)
                myErr = SecTrustedApplicationCreateFromPath( nil, &secApp)
                myACLs = SecAccessCopyMatchingACLList(itemAccess!, kSecACLAuthorizationDecrypt)
                var appList: CFArray? = nil
                var desc: CFString? = nil
                var newacl: AnyObject? = nil
                var prompt = SecKeychainPromptSelector()
                
                for acl in myACLs as! Array<SecACL> {
                    SecACLCopyContents(acl, &appList, &desc, &prompt)
                    newacl = acl
                    
                    if appList != nil {
                        var newAppList = appList.unsafelyUnwrapped as! Array<SecTrustedApplication>
                        
                        newAppList.append(secApp!)
                        
                        // adding NoMAD to the ACL app list
                        myErr = SecACLSetContents(acl, newAppList as CFArray, "No Prompt" as CFString, SecKeychainPromptSelector.invalidAct)
                    }
                }
                
                myErr = SecKeychainItemSetAccessWithPassword(myKeychainItem, itemAccess!, UInt32(newPassword.characters.count), newPassword)
                
                if myErr != 0 {
                    myLogger.logit(.base, message: "Error setting keychain ACL.")
                }
                
            } else {
                myLogger.logit(.debug, message: "Keychain item \(item.key) : \(item.value) is available via ACLs.")
            }

            myErr = SecItemUpdate(itemSearch as CFDictionary, attrToUpdate as CFDictionary)

            if myErr == 0 {
                myLogger.logit(.debug, message: "Updated password for service: \(item.key)")
            } else {
                myLogger.logit(.debug, message: "Failed to update password for service: \(item.key)")
            }
            
            // For internet passwords - we'll have to loop through this all again
            
            //itemSearch[kSecClass as String ] = kSecClassInternetPassword
        }
    }
}
