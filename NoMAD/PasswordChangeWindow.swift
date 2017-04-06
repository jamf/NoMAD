//
//  PasswordChangeWindow.swift
//  NoMAD
//
//  Created by Joel Rennich on 4/26/16.
//  Copyright © 2016 Trusource Labs. All rights reserved.
//

import Cocoa

protocol PasswordChangeDelegate {
    func updateUserInfo()
}

class PasswordChangeWindow: NSWindowController, NSWindowDelegate, NSTextFieldDelegate {

    var delegate: PasswordChangeDelegate?

    @IBOutlet weak var newPassword: NSSecureTextField!
    @IBOutlet weak var oldPassword: NSSecureTextField!
    @IBOutlet weak var newPasswordAgain: NSSecureTextField!
    @IBOutlet weak var passwordChangeButton: NSButton!
    @IBOutlet weak var HelpButton: NSButton!
    @IBOutlet weak var passwordChangeSpinner: NSProgressIndicator!

    // password policy

    @IBOutlet weak var secondaryAlert: NSButton!
    @IBOutlet weak var policyAlert: NSButton!
    let caps: Set<Character> = Set("ABCDEFGHIJKLKMNOPQRSTUVWXYZ".characters)
    let lowers: Set<Character> = Set("abcdefghijklmnopqrstuvwxyz".characters)
    let numbers: Set<Character> = Set("1234567890".characters)
    let symbols: Set<Character> = Set("!\"@#$%^&*()_-+={}[]|:;<>,.?~`\\/".characters)
    var passwordPolicy = [String : AnyObject ]()

    var minLength: String = "0"
    var minUpperCase: String = "0"
    var minLowerCase: String = "0"
    var minNumber: String = "0"
    var minSymbol: String = "0"
    var minMatches: String = "0"

    override var windowNibName: String! {
        return "PasswordChangeWindow"
    }

    override func windowDidLoad() {

        super.windowDidLoad()

        self.window?.center()

        // load in the password policy

        if defaults.dictionary(forKey: Preferences.passwordPolicy) != nil {
        passwordPolicy = defaults.dictionary(forKey: Preferences.passwordPolicy)! as [String : AnyObject ]
            minLength = passwordPolicy["minLength"] as! String
            minUpperCase = passwordPolicy["minUpperCase"] as! String
            minLowerCase = passwordPolicy["minLowerCase"] as! String
            minNumber = passwordPolicy["minNumber"] as! String
            minSymbol = passwordPolicy["minSymbol"] as! String
            if passwordPolicy["minMatches"] != nil {
                minMatches = passwordPolicy["minMatches"] as! String
            }

            // set up a text field delegate
            newPassword.delegate = self
            newPasswordAgain.delegate = self
            policyAlert.image = NSImage.init(imageLiteralResourceName: NSImageNameStatusUnavailable)
            secondaryAlert.image = NSImage.init(imageLiteralResourceName: NSImageNameStatusUnavailable)

            passwordChangeButton.isEnabled = false
        }

        // blank out the password fields
        oldPassword.stringValue = ""
        newPassword.stringValue = ""
        newPasswordAgain.stringValue = ""

        // show the policy button

        if let passwordPolicyText = defaults.string(forKey: Preferences.messagePasswordChangePolicy) {
            HelpButton.isEnabled = true
            HelpButton.isHidden = false
        } else {
            HelpButton.isEnabled = false
            HelpButton.isHidden = true
        }

        // set the button text
        passwordChangeButton.title = "NoMADMenuController-ChangePassword".translate
        self.window?.title = "NoMADMenuController-ChangePassword".translate

    }

    func windowWillClose(_ notification: Notification) {

        // blank out the password fields
        oldPassword.stringValue = ""
        newPassword.stringValue = ""
        newPasswordAgain.stringValue = ""

        // Update the Menubar info.
        delegate?.updateUserInfo()
    }

    @IBAction func changePasswordClicked(_ sender: AnyObject) {

        // start the spinner
        passwordChangeSpinner.isHidden = false
        passwordChangeSpinner.startAnimation(nil)

        let userPrincipal = defaults.string(forKey: Preferences.userPrincipal)!.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let currentPassword = oldPassword.stringValue
        let newPassword1 = newPassword.stringValue
        let newPassword2 = newPasswordAgain.stringValue

        // If the user entered the same value for both password fields.
        if ( newPassword1 == newPassword2) {
            var myError = ""

            myError = performPasswordChange(username: userPrincipal, currentPassword: currentPassword, newPassword1: newPassword1, newPassword2: newPassword2)

            // put password in keychain, but only if there was no error
            /*
             if ( defaults.boolForKey("UseKeychain") && myError != "" ) {

             // check if keychain item exists and delete it if it does

             let myKeychainUtil = KeychainUtil()

             myKeychainUtil.findAndDelete(userPrincipal)

             myKeychainUtil.setPassword(userPrincipal, pass: newPassword1)
             }
             */
            if myError != "" {
                let alertController = NSAlert()
                var errorText = myError

                // make errors more readable

                if myError.contains("Failed to change invalid password: 4") {
                    errorText = "New password doesn't meet policy requirements."
                }

                alertController.messageText = errorText
                alertController.beginSheetModal(for: self.window!, completionHandler: nil)
                passwordChangeSpinner.isHidden = true
                passwordChangeSpinner.stopAnimation(nil)
                EXIT_FAILURE
            } else {
                let alertController = NSAlert()
                alertController.messageText = "PasswordChangeSuccessful".translate

                passwordChangeSpinner.isHidden = true
                passwordChangeSpinner.stopAnimation(nil)

                // fire off the password change script

                if let passwordChangeScript = defaults.string(forKey: Preferences.changePasswordCommand) {
                    let myResult = cliTask(passwordChangeScript)
                    myLogger.logit(LogLevel.base, message: myResult)
                }

                alertController.beginSheetModal(for: self.window!, completionHandler: {( response ) in
                    if ( response == 0 ) {
                        self.close()
                    } else {
                        self.close()
                    }
                })
            }
            myLogger.logit(.base, message: myError)
        } else {

            let alertController = NSAlert()
            alertController.messageText = "PasswordMismatch".translate
            alertController.beginSheetModal(for: self.window!, completionHandler: nil)
            EXIT_FAILURE
        }
    }

    @IBAction func HelpButtonClicked(_ sender: Any) {

        let alertController = NSAlert()
        alertController.messageText = defaults.string(forKey: Preferences.messagePasswordChangePolicy)!
        alertController.beginSheetModal(for: self.window!, completionHandler: nil)
    }

    func checkPassword(pass: String) -> String {

        var result = ""

        let capsOnly = String(pass.characters.filter({ (caps.contains($0))}))
        let lowerOnly = String(pass.characters.filter({ (lowers.contains($0))}))
        let numberOnly = String(pass.characters.filter({ (numbers.contains($0))}))
        let symbolOnly = String(pass.characters.filter({ (symbols.contains($0))}))

        if passwordPolicy.count != 0 {

            var totalMatches = 0

            if pass.characters.count < Int(minLength)! {
                result.append("Length requirement not met.\n")
            }

            if capsOnly.characters.count < Int(minUpperCase)! {
                result.append("Upper case character requirement not met.\n")
            } else {
                totalMatches += 1
            }

            if lowerOnly.characters.count < Int(minLowerCase)! {
                result.append("Lower case character requirement not met.\n")
            } else {
                totalMatches += 1
            }

            if numberOnly.characters.count < Int(minNumber)! {
                result.append("Numeric character requirement not met.\n")
            } else {
                totalMatches += 1
            }

            if symbolOnly.characters.count < Int(minSymbol)! {
                result.append("Symbolic character requirement not met.\n")
            } else {
                totalMatches += 1
            }

            if totalMatches >= Int(minMatches)! && Int(minMatches) != 0 {
                result = ""
            }
        }

        return result
    }

    override func controlTextDidChange(_ obj: Notification) {
        let error = checkPassword(pass: newPassword.stringValue)

        if error == "" {
            policyAlert.image = NSImage.init(imageLiteralResourceName: NSImageNameStatusAvailable)
        } else {
            policyAlert.image = NSImage.init(imageLiteralResourceName: NSImageNameStatusUnavailable)
            policyAlert.toolTip = error
            passwordChangeButton.isEnabled = false

        }

        if newPasswordAgain.stringValue == newPassword.stringValue && error == "" {
            secondaryAlert.image = NSImage.init(imageLiteralResourceName: NSImageNameStatusAvailable)
            passwordChangeButton.isEnabled = true

        } else {
            secondaryAlert.image = NSImage.init(imageLiteralResourceName: NSImageNameStatusUnavailable)
            secondaryAlert.toolTip = "Passwords don't match."
            passwordChangeButton.isEnabled = false

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
    /*
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
     let remoteUserPasswordIsCorrect = noMADUser.checkRemoteUserPassword(currentPassword)
     // Checks if console password is correct. If it is,
     // then change tha
     let consoleUserPasswordIsCorrect = noMADUser.checkCurrentConsoleUserPassword(currentPassword)
     // Checks if keychain password is cofrect
     let keychainPasswordIsCorrect = try noMADUser.checkKeychainPassword(currentPassword)
     //
     let useKeychain = defaults.bool(forKey: "UseKeychain")
     //
     var doLocalPasswordSync = false
     if defaults.integer(forKey: LocalPasswordSync) == 1 {
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
     myLogger.logit(LogLevel.debug, message: "Console user is AD, trying to change using console password.")
     // Check if the current password entered matches the console user.
     guard consoleUserPasswordIsCorrect else {
					myError = "Current password does not match console user's password. Can't change console user's password."
					return myError
     }

     // Try to change the password using the remote method
     // Because the current console user is not AD.
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
     */


    // username must be of the format username@kerberosRealm
    // TODO: Old Method. Delete
    /*
     func performPasswordChange(username: String, currentPassword: String, newPassword1: String, newPassword2: String) -> String {
     var myError: String = ""

     if (currentPassword.isEmpty || newPassword1.isEmpty || newPassword2.isEmpty) {
     myLogger.logit(.info, message: "Some of the fields are empty")
     myError = "All fields must be filled in"
     return myError
     } else {
     myLogger.logit(.info, message: "All fields are filled in, continuing")
     }

     // If the user entered the same value for both password fields.
     if ( newPassword1 == newPassword2 ) {
     let localPasswordSync = defaults.integerForKey("LocalPasswordSync")

     let ChangePassword: KerbUtil = KerbUtil()
     myLogger.logit(.base, message: "Change password for " + username )

     // check to see we can match the kpasswd server with the LDAP server
     let kerbPrefFile = checkKpasswdServer(true)

     myError = ChangePassword.changeKerbPassword(currentPassword, newPassword1, username)

     if ( defaults.boolForKey("UseKeychain") ) {

     // check if keychain item exists
     let myKeychainUtil = KeychainUtil()

     do {
					try myKeychainUtil.findPassword(username)
     } catch {
					myKeychainUtil.setPassword(username, pass: newPassword1)
     }
     }
     // If there wasn't an error and Sync Local Password is set
     // Check if the old password entered matches the current local password
     if (localPasswordSync == 1 ) && myError == "" {
     var UserPasswordSetDates = [String:AnyObject]()

     // update the password set database
     if defaults.dictionaryForKey("UserPasswordSetDates") != nil {
     UserPasswordSetDates = defaults.dictionaryForKey("UserPasswordSetDates")!
     }

     UserPasswordSetDates[username] = "just set"
     defaults.setObject(UserPasswordSetDates, forKey: "UserPasswordSetDates")

     do {
					try testLocalPassword(currentPassword)
     } catch {
					myLogger.logit(LogLevel.info, message: "Local password check Swift = no")
					myError = "Your current local password does not match your AD password."
     }
     }

     if kerbPrefFile {
     let kerbDefaults = NSUserDefaults(suiteName: "com.apple.Kerberos")

     // TODO: Replace defaults delete.
     cliTask("/usr/bin/defaults delete com.apple.Kerberos")
     }

     // If there wasn't an error and Sync Local Password is set
     // Update the keychain password
     if (localPasswordSync == 1 ) && myError == "" {
     if (ChangePassword.changeKeychainPassword(currentPassword, newPassword1) == 0) {
					myLogger.logit(.base, message: "Error changing local keychain")
					myError = "Could not change your local keychain password."
     }
     }

     // If there wasn't an error and Sync Local Password is set
     // Update the local password
     if (localPasswordSync == 1 ) && myError == "" {
     do { try changeLocalPassword( currentPassword, newPassword: newPassword1) }
     catch {
					myLogger.logit(.base, message: "Local password change failed")
					myError = "Local password change failed"
     }
     }
     } else {
     myError = "New passwords don't match."
     }
     return myError
     }
     */

    // Verifies the entered old Password matches the local password so it can change it.
    /*
     private func testLocalPassword(password: String) throws {
     let myUser = NSUserName()
     let session = ODSession.defaultSession()
     let node = try ODNode.init(session: session, type: UInt32(kODNodeTypeAuthentication))
     let query = try ODQuery.init(node: node, forRecordTypes: kODRecordTypeUsers, attribute: kODAttributeTypeRecordName, matchType: UInt32(kODMatchEqualTo), queryValues: myUser, returnAttributes: kODAttributeTypeNativeOnly, maximumResults: 0)
     let result = try query.resultsAllowingPartial(false)
     let record: ODRecord = result[0] as! ODRecord
     try record.verifyPassword(password)
     }

     // Needed to attempt to sync local password with AD on login.
     private func changeLocalPassword(oldPassword: String, newPassword: String) throws -> Bool {
     let myUser = NSUserName()
     let session = ODSession.defaultSession()
     let node = try ODNode.init(session: session, type: UInt32(kODNodeTypeAuthentication))
     let query = try ODQuery.init(node: node, forRecordTypes: kODRecordTypeUsers, attribute: kODAttributeTypeRecordName, matchType: UInt32(kODMatchEqualTo), queryValues: myUser, returnAttributes: kODAttributeTypeNativeOnly, maximumResults: 0)
     //let result = try query.resultsAllowingPartial(false)
     var result: [ODRecord] = []
     do {
     result = try query.resultsAllowingPartial(false) as! [ODRecord]
     } catch let error as NSErrorPointer {
     myLogger.logit(LogLevel.base, message: "Recieved error getting change local password results: " + error.debugDescription)
     return false
     }
     if (result.count > 0) {
     let record: ODRecord = result[0]
     do {
     try record.changePassword(oldPassword, toPassword: newPassword)
     //ODRecordChangePassword(<#T##record: ODRecordRef!##ODRecordRef!#>, <#T##oldPassword: CFString!##CFString!#>, <#T##newPassword: CFString!##CFString!#>, <#T##error: UnsafeMutablePointer<Unmanaged<CFError>?>##UnsafeMutablePointer<Unmanaged<CFError>?>#>)
     } catch let error as NSErrorPointer {
     myLogger.logit(LogLevel.base, message: "Recieved error getting change local password results: " + error.debugDescription)
     return false
     }
     return true
     } else  {
     return false
     }
     }

     // write out local krb5.conf file to ensure password change happens to the same kdc as we're using for LDAP
     private func checkKpasswdServer(writePref: Bool ) -> Bool {

     let myLDAPServers = LDAPServers()
     myLDAPServers.setDomain(defaults.stringForKey("ADDomain")!)

     guard let adDomain = defaults.stringForKey("ADDomain") else {
     myLogger.logit(LogLevel.base, message: "Preferences does not contain a value for the AD Domain.")
     return false
     }

     let myKpasswdServers = myLDAPServers.getSRVRecords(adDomain, srv_type: "_kpasswd._tcp.")

     if myKpasswdServers.contains(myLDAPServers.currentServer) {

     if writePref {
     // check to see if a file exists already

     let myFileManager = NSFileManager()
     let myPrefFile = NSHomeDirectory().stringByAppendingString("/Library/Preferences/com.apple.Kerberos.plist")
     
     if ( !myFileManager.fileExistsAtPath(myPrefFile)) {
     // no existing pref file
     
     let data = NSMutableDictionary()
     let realms = NSMutableDictionary()
     let realm = NSMutableDictionary()
     
     realm.setValue(myLDAPServers.currentServer, forKey: "kdc")
     realm.setValue(myLDAPServers.currentServer, forKey: "kpasswd")
     
     realms.setObject(realm, forKey: defaults.stringForKey("KerberosRealm")!)
     data.setObject(realms, forKey: "realms")
     
     return data.writeToFile(myPrefFile, atomically: true)
     
     }
     return false
     }
     return false
     } else {
     return false
     }
     }
     */
}
