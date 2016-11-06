//
//  NoMADUser.swift
//  NoMAD
//
//  Created by Boushy, Phillip on 10/12/16.
//  Copyright © 2016 Trusource Labs. All rights reserved.
//

import Foundation
import SystemConfiguration
import SecurityFoundation


enum NoMADUserError: Error, CustomStringConvertible {
    case itemNotFound(String)
    case invalidParamater(String)
    case invalidResult(String)
    case unknownError(String)

    var description: String {
        switch self {
        case .itemNotFound(let message): return message
        case .invalidParamater(let message): return message
        case .invalidResult(let message): return message
        case .unknownError(let message): return message
        }
    }
}
/*
 extension NoMADUserError {
	var description: String {

	}
 }
 */
class NoMADUser {
    var kerberosPrincipal: String // the Kerberos principal that is currently signed in to NoMAD.
    var userName: String// the username that was used to Sign In
    var realm: String // the realm that NoMAD is connected to.

    static let currentConsoleUserName: String = NSUserName()
    static let uid: String = String(getuid())
    fileprivate let currentConsoleUserRecord: ODRecord

    init(kerberosPrincipal: String) throws {
        self.kerberosPrincipal = kerberosPrincipal
        let kerberosPrincipalArray = kerberosPrincipal.components(separatedBy: "@")
        guard kerberosPrincipalArray.count == 2 else {
            myLogger.logit(LogLevel.debug, message: "Kerberos principal is in the wrong format, should be username@REALM")
            throw NoMADUserError.invalidParamater("Kerberos principal is in the wrong format, should be username@REALM")
        }
        userName = kerberosPrincipalArray[0]
        realm = kerberosPrincipalArray[1]
        guard let unwrappedCurrentConsoleUserRecord = NoMADUser.getCurrentConsoleUserRecord() else {
            myLogger.logit(LogLevel.debug, message: "Unable to get ODRecord for the current console user.")
            throw NoMADUserError.invalidResult("Unable to get ODRecord for the current console user.")
        }
        currentConsoleUserRecord = unwrappedCurrentConsoleUserRecord
    }

    // MARK: Read-Only Functions
    /**
     Checks if the current console user is an AD account

     - returns:
     A bool
     */
    func currentConsoleUserIsADuser() -> Bool {
        if let originalNodeName = try? String(describing: currentConsoleUserRecord.values(forAttribute: kODAttributeTypeOriginalNodeName)[0]) {
            if ( originalNodeName.contains("/Active Directory")) {
                myLogger.logit(LogLevel.debug, message: "Current Console User is an AD user.")
                return originalNodeName.contains("/Active Directory")
            }
        } else {
            myLogger.logit(LogLevel.debug, message: "Current Console User is not an AD user.")
        }
        return false
    }


    func getCurrentConsoleUserKerberosPrincipal() -> String {
        if currentConsoleUserIsADuser() {

            if let originalAuthenticationAuthority = try? String(describing: currentConsoleUserRecord.values(forAttribute: "dsAttrTypeStandard:OriginalAuthenticationAuthority")[0]) {
                let range = originalAuthenticationAuthority.range(of: "(?<=Kerberosv5;;).+@[^;]+", options:.regularExpression)
                if range != nil {
                    return originalAuthenticationAuthority.substring(with: range!)
                }
                myLogger.logit(LogLevel.debug, message: "Somehow an AD user does not have OriginalAuthenticationAuthority")
            }
            return ""
        } else {
            return ""
        }
    }

    /**
     Checks if the password submitted is correct for the current console user.

     - returns:
     A bool

     - parameters:
     - password: The user's current password as a String.
     */
    func checkCurrentConsoleUserPassword(_ password: String) -> Bool {
        do {
            try currentConsoleUserRecord.verifyPassword(password)
            return true
        } catch let unknownError as NSError {
            myLogger.logit(LogLevel.base, message: "Local User Password is incorrect. Error: " + unknownError.description)
            return false
        }
    }

    /**
     Checks if the password entered is correct for the user account
     that is signed in to NoMAD.

     - returns:
     A bool

     - parameters:
     - password: The user's current password as a String.
     */
    func checkRemoteUserPassword(password: String) -> String? {
        let GetCredentials: KerbUtil = KerbUtil()
        var myError: String? = nil

        myError = GetCredentials.getKerbCredentials( password, kerberosPrincipal )

        return myError
    }

    // Checks if the password entered matches the password
    // for the current console user's default keychain.
    func checkKeychainPassword(_ password: String) throws -> Bool {
        var getDefaultKeychain: OSStatus
        var myDefaultKeychain: SecKeychain?
        var err: OSStatus

        // get the user's default keychain. (Typically login.keychain)
        getDefaultKeychain = SecKeychainCopyDefault(&myDefaultKeychain)
        if ( getDefaultKeychain == errSecNoDefaultKeychain ) {
            throw NoMADUserError.itemNotFound("Could not find Default Keychain")
        }

        // Test if the keychain password is correct by trying to unlock it.
        let passwordLength = UInt32(password.characters.count)
        err = SecKeychainUnlock(myDefaultKeychain, passwordLength, password, true)
        if (err == noErr) {
            return true
        } else if ( err == errSecAuthFailed ) {
            myLogger.logit(LogLevel.base, message: "Authentication failed." + err.description)
            return false
        } else {
            // If we got any other error, we don't know if the password is good or not because we probably couldn't find the keychain.
            myLogger.logit(LogLevel.base, message: "Unknown error: " + err.description)
            throw NoMADUserError.unknownError("Unknown error: " + err.description)
        }

    }

    // MARK: Write Functions
    /**
     Changes the password for the user currently signed into NoMAD.

     - important: You should not try to use this method when the current console user is an AD Account and is the same as the user currently signed into NoMAD.

     - parameters:
     - oldPassword: (String) The user's current password
     - newPassword1: (String) The new password for the user.
     - newPassword2: (String) Must match newPassword1.

     - throws: An error of type NoMADUserError.InvalidParameter

     - returns:
     A string containing any error text from KerbUtil
     */
    func changeRemotePassword(_ oldPassword: String, newPassword1: String, newPassword2: String) throws {
        if (newPassword1 != newPassword2) {
            myLogger.logit(LogLevel.info, message: "New passwords do not match.")
            throw NoMADUserError.invalidParamater("New passwords do not match.")
        }



        let currentConsoleUserKerberosPrincipal = getCurrentConsoleUserKerberosPrincipal()
        if currentConsoleUserIsADuser() {
            if ( kerberosPrincipal == currentConsoleUserKerberosPrincipal ) {
                myLogger.logit(LogLevel.base, message: "User signed into NoMAD is the same as user logged onto console. Console user is AD user. Can't use changeRemotePassword.")
                throw NoMADUserError.invalidParamater("NoMAD User = Console User. Console user is AD user. Can't use changeRemotePassword. Use changeCurrentConsoleUserPassword() instead.")
            } else {
                myLogger.logit(LogLevel.notice, message: "NoMAD User != Console User. Console user is AD user. You should prompt the user to change the local password.")
            }
        }

        let kerbPrefFile = checkKpasswdServer(true)
        guard kerbPrefFile else {
            myLogger.logit(LogLevel.base, message: "Unable to create Kerberos preference file.")
            throw NoMADUserError.itemNotFound("Unable to create Kerberos preference file.")
        }

        let remotePasswordChanger: KerbUtil = KerbUtil()
        let error = remotePasswordChanger.changeKerbPassword(oldPassword, newPassword1, kerberosPrincipal)

        if (error == "") {
            myLogger.logit(LogLevel.info, message: "Successfully changed remote password.")
        } else {
            myLogger.logit(LogLevel.info, message: "Unable to change remote password. Error: " + error!)
            throw NoMADUserError.invalidResult("Unable to change password: " + error!)
        }

        if kerbPrefFile {
            //let kerbDefaults = NSUserDefaults(suiteName: "com.apple.Kerberos")

            // TODO: Replace defaults delete.
            cliTask("/usr/bin/defaults delete com.apple.Kerberos")
        }

    }

    /**
     Changes the password of the user currently logged into the computer.

     - parameters:
     - oldPassword: (String) The user's current password
     - newPassword1: (String) The new password for the user.
     - newPassword2: (String) Must match newPassword1.

     */
    func changeCurrentConsoleUserPassword(_ oldPassword: String, newPassword1: String, newPassword2: String, forceChange: Bool) throws -> Bool {
        if (newPassword1 != newPassword2) {
            myLogger.logit(LogLevel.info, message: "New passwords do not match.")
            throw NoMADUserError.invalidParamater("New passwords do not match.")
        }

        let currentConsoleUserKerberosPrincipal = getCurrentConsoleUserKerberosPrincipal()
        if currentConsoleUserIsADuser() && ( kerberosPrincipal != currentConsoleUserKerberosPrincipal ){
            if ( forceChange ) {
                myLogger.logit(LogLevel.debug, message: "NoMAD User != Console User. Console user is AD user. Hopefully you prompted the user.")
            } else {
                myLogger.logit(LogLevel.debug, message: "NoMAD User != Console User. Console user is AD user. Preventing change as safety precaution.")
                throw NoMADUserError.invalidParamater("Console user is an AD account, you need to force change the password. You should prompt the user before doing this.")
            }
        }

        do {
            try currentConsoleUserRecord.changePassword(oldPassword, toPassword: newPassword1)
            return true
        } catch let unknownError as NSError {
            myLogger.logit(LogLevel.base, message: "Local User Password is incorrect. Error: " + unknownError.description)
            return false
        }
    }

    func changeKeychainPassword(_ oldPassword: String, newPassword1: String, newPassword2: String) throws {
        if (newPassword1 != newPassword2) {
            myLogger.logit(LogLevel.info, message: "New passwords do not match.")
            throw NoMADUserError.invalidParamater("New passwords do not match.")
        }

        var getDefaultKeychain: OSStatus
        var myDefaultKeychain: SecKeychain?
        var err: OSStatus

        // get the user's default keychain. (Typically login.keychain)
        getDefaultKeychain = SecKeychainCopyDefault(&myDefaultKeychain)
        if ( getDefaultKeychain == errSecNoDefaultKeychain ) {
            throw NoMADUserError.itemNotFound("Could not find Default Keychain")
        }

        // Test if the keychain password is correct by trying to unlock it.
        let oldPasswordLength = UInt32(oldPassword.characters.count)
        let newPasswordLength = UInt32(newPassword1.characters.count)

        err = SecKeychainChangePassword(myDefaultKeychain, oldPasswordLength, oldPassword, newPasswordLength, newPassword1)
        if (err == noErr) {
            myLogger.logit(LogLevel.info, message: "Changed keychain password successfully.")
            return
        } else if ( err == errSecAuthFailed ) {
            myLogger.logit(LogLevel.base, message: "Keychain password was incorrect.")
            return
        } else {
            // If we got any other error, we don't know if the password is good or not because we probably couldn't find the keychain.
            myLogger.logit(LogLevel.base, message: "Unknown error: " + err.description)
            throw NoMADUserError.unknownError("Unknown error: " + err.description)
        }
    }

    func updateKeychainItem(_ newPassword1: String, newPassword2: String) throws -> Bool {
        if (newPassword1 != newPassword2) {
            myLogger.logit(LogLevel.info, message: "New passwords do not match.")
            throw NoMADUserError.invalidParamater("New passwords do not match.")
        }
        let keychainUtil = KeychainUtil()
        var status: Bool = false

        status = keychainUtil.updatePassword(kerberosPrincipal, pass: newPassword1)

        return status
    }



    // MARK: Class Functions
    // Get ODRecord for the user that is currently logged in to the computer.
    class func getCurrentConsoleUserRecord() -> ODRecord? {
        // Get ODRecords where record name is equal to the Current Console User's username
        let session = ODSession.default()
        var records = [ODRecord]()
        do {
            //let node = try ODNode.init(session: session, type: UInt32(kODNodeTypeAuthentication))
            let node = try ODNode.init(session: session, type: UInt32(kODNodeTypeLocalNodes))
            let query = try ODQuery.init(node: node, forRecordTypes: kODRecordTypeUsers, attribute: kODAttributeTypeRecordName, matchType: UInt32(kODMatchEqualTo), queryValues: currentConsoleUserName, returnAttributes: kODAttributeTypeNativeOnly, maximumResults: 0)
            records = try query.resultsAllowingPartial(false) as! [ODRecord]
        } catch {
            myLogger.logit(LogLevel.base, message: "Unable to get local user account ODRecords")
        }


        // We may have gotten multiple ODRecords that match username,
        // So make sure it also matches the UID.
        if ( records != nil ) {
            for case let record in records {
                let attribute = "dsAttrTypeStandard:UniqueID"
                if let odUid = try? String(describing: record.values(forAttribute: attribute)[0]) {
                    if ( odUid == uid) {
                        return record
                    }
                }
            }
        }
        return nil
    }


}






/**
 Changes the remote and current console user's password based on if the
 current console user is an AD account, and if localPasswordSync is enabled.

 - parameters:
 - username: (String) Must be in the format username@REALM
 - currentPassword: (String) The user's current password
 - newPassword1: (String) The new password for the user.
 - newPassword2: (String) Must match newPassword1.

 */
func performPasswordChange(username: String, currentPassword: String, newPassword1: String, newPassword2: String) -> String {
    var myError: String = ""
    guard ( !currentPassword.isEmpty && !newPassword1.isEmpty && !newPassword2.isEmpty ) else {
        myLogger.logit(LogLevel.base, message: "Some of the fields are empty")
        myError = "All fields must be filled in"
        return myError
    }
    myLogger.logit(LogLevel.info, message: "All fields are filled in, continuing")
    guard (newPassword1 == newPassword2) else {
        myLogger.logit(LogLevel.base, message: "New passwords do not match.")
        myError = "New passwords do not match."
        return myError
    }

    do {
        let noMADUser = try NoMADUser(kerberosPrincipal: username)

        // Checks if the remote users's password is correct.
        // If it is and the current console user is not an
        // AD account, then we'll change it.
        var remoteUserPasswordIsCorrect = false

        // treat password expired as a soft erorr and continue

        if ( noMADUser.checkRemoteUserPassword(password: currentPassword) == nil || noMADUser.checkRemoteUserPassword(password: currentPassword) == "Password has expired" ) {
            remoteUserPasswordIsCorrect = true
        }
        // Checks if console password is correct.
        let consoleUserPasswordIsCorrect = noMADUser.checkCurrentConsoleUserPassword(currentPassword)
        // Checks if keychain password is correct
        let keychainPasswordIsCorrect = try noMADUser.checkKeychainPassword(currentPassword)
        // Check if we want to store the password in the keychain.
        let useKeychain = defaults.bool(forKey: "UseKeychain")
        // Check if we want to sync the console user's password with the remote AD password.
        // Only used if console user is not AD.
        var doLocalPasswordSync = false
        if defaults.integer(forKey: "LocalPasswordSync") == 1 {
            doLocalPasswordSync = true
        }

        let consoleUserIsAD = noMADUser.currentConsoleUserIsADuser()


        if !consoleUserIsAD {
            myLogger.logit(LogLevel.debug, message: "Console user is not AD, trying to change using remote password.")
            // Check if the current password entered matches the remote user.
            guard remoteUserPasswordIsCorrect else {
                myError = "Current password does not match remote user's password. Can't perform change."
                return myError
            }

            // Try to change the password using the remote method
            // Because the current console user is not AD.
            do {
                try noMADUser.changeRemotePassword(currentPassword, newPassword1: newPassword1, newPassword2: newPassword2)
            } catch let error as NoMADUserError {
                myLogger.logit(LogLevel.base, message: error.description)
                return error.description
            } catch {
                return "Unknown error changing remote password"
            }
        }


        if consoleUserIsAD || doLocalPasswordSync {
            if consoleUserIsAD {
                myLogger.logit(LogLevel.debug, message: "Console user is AD, trying to change using console password.")
            }
            if doLocalPasswordSync && !consoleUserIsAD {
                myLogger.logit(LogLevel.debug, message: "Local Password sync is enabled, let's try to sync.")
            }
            // Check if the current password entered matches the console user.
            guard consoleUserPasswordIsCorrect else {
                myError = "Current password does not match console user's password. Can't change console user's password."
                return myError
            }

            // Try to change the current console user's password.
            do {
                try noMADUser.changeCurrentConsoleUserPassword(currentPassword, newPassword1: newPassword1, newPassword2: newPassword2, forceChange: true)
            } catch let error as NoMADUserError {
                myLogger.logit(LogLevel.base, message: error.description)
                return error.description
            } catch {
                return "Unknown error changing current console user password"
            }

            myLogger.logit(LogLevel.debug, message: "Now that we've changed the console user's password, let's try to change the keychain password.")
            guard keychainPasswordIsCorrect else {
                myError = "Current password does not match the keychain's password. Can't change keychain password."
                return myError
            }

            // Try to change the password using the remote method
            // Because the current console user is not AD.
            do {
                try noMADUser.changeKeychainPassword(currentPassword, newPassword1: newPassword1, newPassword2: newPassword2)
            } catch let error as NoMADUserError {
                myLogger.logit(LogLevel.base, message: error.description)
                return error.description
            } catch {
                return "Unknown error changing keychain password"
            }
        }
        
        if useKeychain {
            do {
                try noMADUser.updateKeychainItem(newPassword1, newPassword2: newPassword2)
            } catch let error as NoMADUserError {
                myLogger.logit(LogLevel.base, message: error.description)
                return error.description
            } catch {
                return "Unknown error updating keychain item"
            }
        }
        
    } catch let error as NoMADUserError {
        myLogger.logit(LogLevel.base, message: error.description)
        return error.description
    } catch let error as NSError {
        myLogger.logit(LogLevel.base, message: error.description)
        return error.description
    } catch {
        return "Unknown error"
    }
    
    return myError
}


private func checkKpasswdServer(_ writePref: Bool ) -> Bool {
    
    guard let adDomain = defaults.string(forKey: "ADDomain") else {
        myLogger.logit(LogLevel.base, message: "Preferences does not contain a value for the AD Domain.")
        return false
    }
    
    let myLDAPServers = LDAPServers()
    myLDAPServers.setDomain(adDomain)
    
    
    
    let myKpasswdServers = myLDAPServers.getSRVRecords(adDomain, srv_type: "_kpasswd._tcp.")
    myLogger.logit(LogLevel.debug, message: "Current Server is: " + myLDAPServers.currentServer)
    myLogger.logit(LogLevel.debug, message: "Kpasswd Servers are: " + myKpasswdServers.description)
    
    if myKpasswdServers.contains(myLDAPServers.currentServer) {
        myLogger.logit(LogLevel.debug, message: "Found kpasswd server that matches current LDAP server.")
        if writePref {
            myLogger.logit(LogLevel.debug, message: "Developer says we should write the preference file.")
            // check to see if a file exists already
            
            let myFileManager = FileManager()
            let myPrefFile = NSHomeDirectory() + "/Library/Preferences/com.apple.Kerberos.plist"
            
            if ( !myFileManager.fileExists(atPath: myPrefFile)) {
                myLogger.logit(LogLevel.debug, message: "The Kerberos plist doesn't exist already, so we're going to create it now.")
                // no existing pref file
                
                let data = NSMutableDictionary()
                let realms = NSMutableDictionary()
                let realm = NSMutableDictionary()
                
                realm.setValue(myLDAPServers.currentServer, forKey: "kdc")
                realm.setValue(myLDAPServers.currentServer, forKey: "kpasswd")
                
                realms.setObject(realm, forKey: defaults.string(forKey: "KerberosRealm")! as NSCopying)
                data.setObject(realms, forKey: "realms" as NSCopying)
                
                return data.write(toFile: myPrefFile, atomically: true)
                
            }
            return false
        }
        return false
    } else {
        myLogger.logit(LogLevel.base, message: "Couldn't find kpasswd server that matches current LDAP server.")
        return false
    }
}
