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
    var expireDate : NSDate
}

class KeychainUtil {
    
    var myErr: OSStatus
    let serviceName = "NoMAD"
    var passLength: UInt32 = 0
    var passPtr: UnsafeMutablePointer<Void> = nil
    
    var myKeychainItem: SecKeychainItem?
    
    init() {
        myErr = 0
    }
    
    // find if there is an existing account password and return it or throw
    
    func findPassword(name: String) throws -> String {
        
        myErr = SecKeychainFindGenericPassword(nil, UInt32(serviceName.characters.count), serviceName, UInt32(name.characters.count), name, &passLength, &passPtr, &myKeychainItem)

        if myErr == OSStatus(errSecSuccess) {
            let password = NSString(bytes: passPtr, length: Int(passLength), encoding: NSUTF8StringEncoding)
            return password as! String
        } else {
            throw NoADError.NoStoredPassword
        }
    }
    
    // set the password
    
    func setPassword(name: String, pass: String) -> OSStatus {

        myErr = SecKeychainAddGenericPassword(nil, UInt32(serviceName.characters.count), serviceName, UInt32(name.characters.count), name, UInt32(pass.characters.count), pass, nil)
        
        return myErr
    }
    
    // delete the password from the keychain
    
    func deletePassword() -> OSStatus {
        myErr = SecKeychainItemDelete(myKeychainItem!)
        return myErr
    }

    // convience functions
    
    func findAndDelete(name: String) -> Bool {
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
    
    // return a Dictionary of all the certs a user has that match their name and domain
    
    func findCerts(user: String, defaultNamingContext: String) -> NSDate {
        
        var myCert: SecCertificate? = nil
        var out: AnyObject? = nil
        
        // create a search dictionary to find Identitys with Private Keys and returning all matches
        // TODO: Tweak this to find the best mix
        
        /*
 @constant kSecMatchIssuers Specifies a dictionary key whose value is a
 CFArray of X.500 names (of type CFDataRef). If provided, returned
 certificates or identities will be limited to those whose
 certificate chain contains one of the issuers provided in this list.
 */
 
        let identitySearchDict: [String:AnyObject] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate as String as String as AnyObject,
            // this matches e-mail address
            //kSecMatchEmailAddressIfPresent as String : email as CFString,
            
            // this matches Common Name
            kSecMatchSubjectContains as String : user as CFString,
            
            kSecReturnRef as String: true as AnyObject,
            kSecMatchLimit as String : kSecMatchLimitAll as AnyObject
        ]
        //var myCerts = [certDates]()
        
        myErr = 0
        var lastExpire: NSDate = NSDate.distantPast()
        
        // look for all matches
        
        myErr = SecItemCopyMatching(identitySearchDict as CFDictionary, &out)
        
        if myErr != 0 {
            myLogger.logit(0, message: "Error getting Certificates.")
            EXIT_FAILURE
        }
        
        let myArray = out as! CFArray as Array
        
        //var emails: CFArray? = nil
        
        for item in myArray {
            
            myErr = SecIdentityCopyCertificate(item as! SecIdentity, &myCert)
            
            if myErr != 0 {
                myLogger.logit(0, message: "Error getting Certificate references.")
                EXIT_FAILURE
            }
                    
                    // get the full OID set for the cert
                    
                    let myOIDs : NSDictionary = SecCertificateCopyValues(myCert!, nil, nil)!
            
                    // find the LDAP URI to see if it matches our current defaultNamingContex
            
            if myOIDs["1.3.6.1.5.5.7.1.1"] != nil {
                 let URI : NSDictionary = myOIDs["1.3.6.1.5.5.7.1.1"] as! NSDictionary
                    let URIValue = URI["value"]! as! NSArray
                    for values in URIValue {
                        let value = values as! NSDictionary
                        
                        if String(_cocoaString: value["label"]!) == "URI" {

                            if String(value["value"]!).containsString(defaultNamingContext){
                                
                                // we have a match now gather the expire date and the serial
                                
                                let expireOID : NSDictionary = myOIDs["2.5.29.24"]! as! NSDictionary
                                let expireDate = expireOID["value"]! as! NSDate
                                //let serialDict : NSDictionary = myOIDs["2.16.840.1.113741.2.1.1.1.3"]! as! NSDictionary
                                //let serial = serialDict["value"]! as! String
                                
                                // pack the data up into a certDate
                                
                                //let certificate = certDates( serial: serial, expireDate: expireDate)
                                
                                if lastExpire.timeIntervalSinceNow < expireDate.timeIntervalSinceNow {
                                    lastExpire = expireDate
                                }
                                
                                // append to the list
                                
                                //myCerts.append(certificate)
                            }
                        }
                    }
                }
            }
    // }

            return lastExpire
    }
}
