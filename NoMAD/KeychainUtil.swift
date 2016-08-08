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

class KeychainUtil {
    
    // find if there is an existing account password and return it or throw
    
    func findPassword(name: String) throws -> String {
        
        var myErr: OSStatus
        
        let serviceName = "NoMAD"
        var passLength: UInt32 = 0
        var passPtr: UnsafeMutablePointer<Void> = nil
        
        myErr = SecKeychainFindGenericPassword(nil, UInt32(serviceName.characters.count), serviceName, UInt32(name.characters.count), name, &passLength, &passPtr, nil)

        if myErr == OSStatus(errSecSuccess) {
            let password = NSString(bytes: passPtr, length: Int(passLength), encoding: NSUTF8StringEncoding)
            return password as! String
        } else {
            throw NoADError.NoStoredPassword
        }
    }
    
    func setPassword(name: String, pass: String) -> OSStatus {
        var myErr: OSStatus
        
        let serviceName = "NoMAD"
        
        myErr = SecKeychainAddGenericPassword(nil, UInt32(serviceName.characters.count), serviceName, UInt32(name.characters.count), name, UInt32(pass.characters.count), pass, nil)
        
        return myErr
    }
}
