//
//  Login.swift
//  NoMAD
//
//  Created by Joel Rennich on 4/21/16.
//  Copyright © 2016 Trusource Labs. All rights reserved.
//

import Cocoa

protocol LoginWindowDelegate {
    func updateUserInfo()
}

let resetNotificationKey = Notification(name: Notification.Name(rawValue: "resetPassword"), object: nil)

class LoginWindow: NSWindowController, NSWindowDelegate {

    var delegate: LoginWindowDelegate?

    @IBOutlet weak var userName: NSTextField!
    @IBOutlet weak var Password: NSSecureTextField!

    @IBOutlet weak var changePasswordButton: NSButton!
    @IBOutlet weak var newPasswordLabel2: NSTextField!
    @IBOutlet weak var newPasswordLable: NSTextField!
    @IBOutlet weak var passwordLabel: NSTextField!
    @IBOutlet var logInButton: NSButton!
    @IBOutlet weak var changePasswordField1: NSSecureTextField!
    @IBOutlet weak var changePasswordField2: NSSecureTextField!

    //var noMADUser: NoMADUser? = nil


    override var windowNibName: String! {
        return "LoginWindow"
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        guard (( defaults.string(forKey: Preferences.lastUser) ) != "") else {
            self.window?.center()
            setWindowToLogin()
            return
        }

        changePasswordButton.title = "NoMADMenuController-LogIn".translate
        self.window?.title = "NoMAD - " + "NoMADMenuController-LogIn".translate

        userName.stringValue = defaults.string(forKey: Preferences.lastUser)!
        Password.becomeFirstResponder()

        setWindowToLogin()

        self.window?.center()

    }

    func windowWillClose(_ notification: Notification) {
        Password.stringValue = ""
        changePasswordField1.stringValue = ""
        changePasswordField2.stringValue = ""
        setWindowToLogin()
        NotificationCenter.default.post(updateNotification)
        delegate?.updateUserInfo()
    }


    //When the user clicks "sign in" in NoMAD, goes through the steps
    //to login and verify that everything is correct.

    @IBAction func LogInClick(_ sender: Any) {

        var userNameChecked = ""

        // ensure that user entered just a shortname, in which case add the Kerberos realm
        // or if there is an "@" in the name, remove what's after it and put in the AD Domain set in the prefs
        // TODO: support multiple domains at the same time

        if userName.stringValue.contains("@") {
            let split = userName.stringValue.components(separatedBy: "@")
            userNameChecked = split[0] + "@" + defaults.string(forKey: Preferences.kerberosRealm)!
        } else {
            userNameChecked = userName.stringValue + "@" + defaults.string(forKey: Preferences.kerberosRealm)!
        }

        //let GetCredentials: KerbUtil = KerbUtil()
        var myError: String? = ""
        let currentPassword = Password.stringValue

        do {
            let noMADUser = try NoMADUser(kerberosPrincipal: userNameChecked)

            // Checks if the remote users's password is correct.
            // If it is and the current console user is not an
            // AD account, then we'll change it.
            
            myError = noMADUser.checkRemoteUserPassword(password: currentPassword)

            // Let's present any errors we got before we do anything else.
            // We're using guard to check if myError is the correct value
            // because we want to force it to return otherwise.
            guard myError == nil else {
                switch myError! {
                // Password expired, so we need to present a password change window for the user to change it.
                case "Password has expired":
                    defaults.set(userName.stringValue, forKey: Preferences.userPrincipal)
                    //print(userName.stringValue)
                    //print(defaults.string(forKey: "userPrincipal"))
                    let alertController = NSAlert()
                    alertController.messageText = "Your password has expired. Please reset your password now."
                    alertController.addButton(withTitle: "Change Password")
                    alertController.beginSheetModal(for: self.window!, completionHandler: { [unowned self] (returnCode) -> Void in
                        if returnCode == NSAlertFirstButtonReturn {
                            myLogger.logit(.base, message:myError!)
                            self.setWindowToChange()
                        }
                    })
                case "Client (" + userNameChecked + ") unknown":
                    let alertController = NSAlert()
                    alertController.messageText = "Invalid username. Please try again."
                    alertController.beginSheetModal(for: self.window!, completionHandler: nil)
                    myLogger.logit(.base, message:myError!)
                    EXIT_FAILURE
                //
                default:
                    let alertController = NSAlert()
                    alertController.messageText = "Invalid password. Please try again."
                    alertController.beginSheetModal(for: self.window!, completionHandler: nil)
                    myLogger.logit(.base, message:myError!)
                    EXIT_FAILURE
                }
                return
            }


            // Checks if console password is correct.
            let consoleUserPasswordResult = noMADUser.checkCurrentConsoleUserPassword(currentPassword)
            // Checks if keychain password is correct
            let keychainPasswordIsCorrect = try noMADUser.checkKeychainPassword(currentPassword)
            // Check if we want to store the password in the keychain.
            let useKeychain = defaults.bool(forKey: Preferences.useKeychain)
            // Check if we want to sync the console user's password with the remote AD password.
            // Only used if console user is not AD.
            var doLocalPasswordSync = false
            if defaults.bool(forKey: Preferences.localPasswordSync) {
                doLocalPasswordSync = true
            }

            let consoleUserIsAD = noMADUser.currentConsoleUserIsADuser()
            let currentConsoleUserMatchesNoMADUser = noMADUser.currentConsoleUserMatchesNoMADUser()
            
            let passwordChangeMethod: String
            if (consoleUserIsAD && currentConsoleUserMatchesNoMADUser) {
                passwordChangeMethod = "OD"
            } else {
                passwordChangeMethod = "NoMAD"
            }

            // check to see if the keychain password is correct
            // this is specific to the usecase where we're using the keychain, an AD user and
            // the password was changed outside of NoMAD

            if consoleUserIsAD && consoleUserPasswordResult != "Invalid" {

                myLogger.logit(LogLevel.debug, message: "Checking if keychain password needs to be chagned.")

                let keychainUtil = KeychainUtil()

                var storedPassword: String

                do {
                    storedPassword = try keychainUtil.findPassword(userNameChecked) } catch {
                        myLogger.logit(LogLevel.debug, message: "Can't get password from keychain.")
                        storedPassword = currentPassword
                }

                // check to make sure the entered password isn't the stored one

                if storedPassword != currentPassword {
                    // see if the keychain is still unlocked and we can use it
                    let passWrong = try! noMADUser.checkKeychainPassword(storedPassword, true)

                    if passWrong {
                        // we need to update the keychain password to the new one
                        do {
                            try noMADUser.changeKeychainPassword(storedPassword, newPassword1: currentPassword, newPassword2: currentPassword)
                            myLogger.logit(LogLevel.debug, message: "Updating keychain password to the new AD password.")
                        } catch {
                            myLogger.logit(LogLevel.debug, message: "Couldn't update keychain password to the new AD password.")
                        }
                    }
                }
            }

            // make sure the just logged in user is the current user and then reset the password warning
            // TODO: @mactroll - why is this 1296000?
            cliTask("/usr/bin/kswitch -p " + userNameChecked )
            defaults.set(1296000, forKey: Preferences.lastPasswordWarning)

            if ( useKeychain ) {
                do {
                    try noMADUser.updateKeychainItem(currentPassword, newPassword2: currentPassword)
                } catch let error as NoMADUserError {
                    myLogger.logit(LogLevel.base, message: error.description)
                } catch {
                    myLogger.logit(LogLevel.base, message: "Unknown error updating keychain item")
                }
            }
            // If the console user's password is incorrect AND
            // the user has it set to sync the local and remote password AND
            // the console user is not an AD account
            // Then prompt the user for their password
            if consoleUserPasswordResult != "Valid" && doLocalPasswordSync && !consoleUserIsAD {
                myLogger.logit(LogLevel.debug, message:"Local user's password does not match remote user.")
                myLogger.logit(LogLevel.debug, message:"Local Sync is enabled.")
                myLogger.logit(LogLevel.debug, message:"Console user is not an AD account.")
                myLogger.logit(LogLevel.debug, message:"Lets try to sync the passwords, prompting user.")
                let alertController = NSAlert()
                // TODO: replace with localized text
                alertController.messageText = (defaults.string(forKey: Preferences.messageLocalSync) ?? "Your network and local passwords are not the same. Please enter the password for your Mac.")
                alertController.addButton(withTitle: "Sync")
                alertController.addButton(withTitle: "Cancel")
                //alertController.addButton(withTitle: "Sync")

                let localPassword = NSSecureTextField(frame: CGRect(x: 0, y: 0, width: 200, height: 24))
                localPassword.becomeFirstResponder()
                
                alertController.accessoryView = localPassword
                guard self.window != nil else {
                    myLogger.logit(LogLevel.debug, message: "Window does not exist.")
                    EXIT_FAILURE
                    // TODO: figure out if this is the proper way to handle this.
                    return
                }


                alertController.beginSheetModal(for: self.window!, completionHandler: { [unowned self] (returnCode) -> Void in
                    myLogger.logit(LogLevel.debug, message: "Sheet Modal completed")
                    if ( returnCode == NSAlertFirstButtonReturn ) {
                        let currentLocalPassword = localPassword.stringValue
                        let newPassword = self.Password.stringValue
                        let consoleUserPasswordResult = noMADUser.checkCurrentConsoleUserPassword(currentLocalPassword)

                        // Making sure the password entered is correct,
                        // if it's not, let's exit.
                        guard ( consoleUserPasswordResult != "Invalid" ) else {
                            let alertController = NSAlert()
                            alertController.messageText = "Invalid password. Please try again."
                            alertController.beginSheetModal(for: self.window!, completionHandler: nil)
                            if myError != nil {
                            myLogger.logit(.base, message:myError!)
                            }
                            myLogger.logit(.base, message:"Local password wrong.")
                            EXIT_FAILURE
                            // TODO: figure out if this is the proper way to handle this.
                            return
                        }
                        myLogger.logit(.base, message:"Local password is right. Syncing.")

                        do {
                            try noMADUser.changeCurrentConsoleUserPassword(currentLocalPassword, newPassword1: newPassword, newPassword2: newPassword, forceChange: true)
                        } catch {
                            myError = "Could not change the current console user's password."
                        }
                        // Check if we were able to change the local account password.
                        guard myError == nil else {
                            let alertController = NSAlert()
                            alertController.messageText = myError!
                            alertController.beginSheetModal(for: self.window!, completionHandler: nil)
                            myLogger.logit(LogLevel.debug, message:myError!)
                            EXIT_FAILURE
                            // TODO: figure out if this is the proper way to handle this.
                            return
                        }

                        do {
                            try noMADUser.changeKeychainPassword(currentLocalPassword, newPassword1: newPassword, newPassword2: newPassword)
                        } catch {
                            myLogger.logit(LogLevel.base, message: "Error changing keychain password")
                            myError = "Could not change your local keychain password."
                        }
                        self.close()
                    } else {
                        myLogger.logit(.base, message:"Local sync cancelled by user.")
                    }
                })

            } else {
                myLogger.logit(LogLevel.info, message: "Not syncing local account because: ")
                if consoleUserPasswordResult == "Valid" {
                    myLogger.logit(LogLevel.info, message: "Console user's password matches AD already.")
                }
                if !doLocalPasswordSync {
                    myLogger.logit(LogLevel.info, message: "The user/admin doesn't have local password sync enabled.")
                }
                if consoleUserIsAD {
                    myLogger.logit(LogLevel.info, message: "Console user is AD account.")
                }
                self.Password.stringValue = ""
                self.close()
            }
        } catch let nomadUserError as NoMADUserError {
            let alertController = NSAlert()
            alertController.messageText = nomadUserError.description
            alertController.beginSheetModal(for: self.window!, completionHandler: nil)
            myLogger.logit(.base, message:myError!)
            EXIT_FAILURE
            self.Password.stringValue = ""
            self.close()
        } catch {
            let alertController = NSAlert()
            alertController.messageText = "Unknown error."
            alertController.beginSheetModal(for: self.window!, completionHandler: nil)
            myLogger.logit(.base, message:myError!)
            EXIT_FAILURE
            self.Password.stringValue = ""
            self.close()
        }

        // fire off the SignInCommand script if there is one

        if defaults.string(forKey: Preferences.signInCommand) != "" {
            let myResult = cliTask(defaults.string(forKey: Preferences.signInCommand)!)
            myLogger.logit(LogLevel.base, message: myResult)
        }

        // DO NOT put self.close() here to try to save code,
        // it will mess up the local password sync code.
    }

    @IBAction func changePasswordButtonClick(_ sender: AnyObject) {
        let userPrincipal: String
        if userName.stringValue.contains("@") {
            userPrincipal = userName.stringValue
        } else {
            userPrincipal = userName.stringValue + "@" + defaults.string(forKey: Preferences.kerberosRealm)!
        }
        let currentPassword = Password.stringValue
        let newPassword1 = changePasswordField1.stringValue
        let newPassword2 = changePasswordField2.stringValue

        // If the user entered the same value for both password fields.
        if ( newPassword1 == newPassword2) {
            var myError = ""
            myError = performPasswordChange(username: userPrincipal, currentPassword: currentPassword, newPassword1: newPassword1, newPassword2: newPassword2)

            if myError != "" {
                let alertController = NSAlert()
                alertController.messageText = myError
                alertController.beginSheetModal(for: self.window!, completionHandler: nil)
                EXIT_FAILURE
            } else {
                let alertController = NSAlert()
                alertController.messageText = "Password changed successfully. Note: it may take up to an hour for your password expiration time to be updated."

                alertController.beginSheetModal(for: self.window!, completionHandler: {( response ) in
                    if ( response == 0 ) {

                        // login via kinit here with the new password

                        let GetCredentials: KerbUtil = KerbUtil()
                        var myError: String? = ""

                        if myError == "" {
                            if userPrincipal.contains("@") {
                                myError = GetCredentials.getKerbCredentials( newPassword1, userPrincipal );
                            } else {
                                myError = GetCredentials.getKerbCredentials( newPassword1, (userPrincipal + "@" + defaults.string(forKey: Preferences.kerberosRealm)!))
                            }
                        }

                        self.setWindowToLogin()
                        self.close()
                    } else {
                        self.setWindowToLogin()
                        self.close()
                    }
                })
            }
            myLogger.logit(.base, message:myError)
        } else {

            let alertController = NSAlert()
            alertController.messageText = "New passwords don't match!"
            alertController.beginSheetModal(for: self.window!, completionHandler: nil)
            EXIT_FAILURE

        }

        // fire off the SignInCommand script if there is one

        if defaults.string(forKey: Preferences.signInCommand) != "" {
            let myResult = cliTask(defaults.string(forKey: Preferences.signInCommand)!)
            myLogger.logit(LogLevel.base, message: myResult)
        }
    }

    fileprivate func setWindowToLogin() {

        // set the size

        var loginSize = NSSize()
        loginSize.width = 381
        loginSize.height = 114

        // disable the bad things

        changePasswordButton.isHidden = true
        changePasswordButton.isEnabled = false

        changePasswordField1.isHidden = true
        changePasswordField2.isHidden = true
        newPasswordLable.isHidden = true
        newPasswordLabel2.isHidden = true

        // enable the good things

        logInButton.isHidden = false
        logInButton.isEnabled = true

        passwordLabel.stringValue = "Password"
        Password.stringValue = ""

        self.window?.setContentSize(loginSize)

    }

    fileprivate func setWindowToChange() {

        // set the size

        var changeSize = NSSize()
        changeSize.width = 381
        changeSize.height = 178

        // disable the bad things

        changePasswordButton.isHidden = false
        changePasswordButton.isEnabled = true

        changePasswordField1.isHidden = false
        changePasswordField2.isHidden = false
        newPasswordLable.isHidden = false
        newPasswordLabel2.isHidden = false

        // enable the good things

        logInButton.isHidden = true
        logInButton.isEnabled = false

        passwordLabel.stringValue = "Old Password"

        // put focus into the first change field
        
        changePasswordField1.becomeFirstResponder()

        self.window?.setContentSize(changeSize)

    }

    // username must be of the format username@kerberosRealm
    /*
     func performPasswordChange(username: String, currentPassword: String, newPassword1: String, newPassword2: String) -> String {
     let localPasswordSync = defaults.integerForKey("LocalPasswordSync")
     var myError: String = ""

     if (currentPassword.isEmpty || newPassword1.isEmpty || newPassword2.isEmpty) {
     myLogger.logit(.base, message:"Some of the fields are empty")
     myError = "All fields must be filled in"
     return myError
     } else {
     myLogger.logit(.notice, message:"All fields are filled in, continuing")
     }
     // If the user entered the same value for both password fields.
     if ( newPassword1 == newPassword2) {
     let ChangePassword: KerbUtil = KerbUtil()
     myError = ChangePassword.changeKerbPassword(currentPassword, newPassword1, username)
     // If there wasn't an error and Sync Local Password is set
     // Check if the old password entered matches the current local password
     if (localPasswordSync == 1 ) && myError == "" {
     do { try testLocalPassword(currentPassword) }
     catch {
     myLogger.logit(.info, message:"Local password check Swift = no")
     myError = "Your current local password does not match your AD password."
     }
     }

     // update the password in the keychain if we're using it

     if ( defaults.boolForKey("UseKeychain") ) {

     // check if keychain item exists

     let myKeychainUtil = KeychainUtil()

     do { try myKeychainUtil.findPassword(username) } catch {
     myKeychainUtil.setPassword(username, pass: newPassword2)
     }

     }

     // If there wasn't an error and Sync Local Password is set
     // Update the keychain password
     if (localPasswordSync == 1 ) && myError == "" {
     if (ChangePassword.changeKeychainPassword(currentPassword, newPassword1) == 0) {
     myLogger.logit(.info, message:"Error changing local keychain")
     myError = "Could not change your local keychain password."
     }
     }

     // If there wasn't an error and Sync Local Password is set
     // Update the local password
     if (localPasswordSync == 1 ) && myError == "" {
     do { try changeLocalPassword( currentPassword, newPassword: newPassword1) }
     catch {
     myLogger.logit(.base, message:"Local password change failed")
     myError = "Local password change failed"
     }
     }
     }
     return myError
     }
     */
    // TODO: Clean this up.
    private func testLocalPassword(password: String) throws {
        let myUser = NSUserName()
        let session = ODSession.default()
        let node = try ODNode.init(session: session, type: UInt32(kODNodeTypeAuthentication))
        let query = try ODQuery.init(node: node, forRecordTypes: kODRecordTypeUsers, attribute: kODAttributeTypeRecordName, matchType: UInt32(kODMatchEqualTo), queryValues: myUser, returnAttributes: kODAttributeTypeNativeOnly, maximumResults: 0)
        let result = try query.resultsAllowingPartial(false)
        let record: ODRecord = result[0] as! ODRecord
        try record.verifyPassword(password)
    }

    // TODO: Clean this up.
    // Needed to attempt to sync local password with AD on login.
    fileprivate func changeLocalPassword(_ oldPassword: String, newPassword: String) throws -> Bool {
        let myUser = NSUserName()
        let session = ODSession.default()
        let node = try ODNode.init(session: session, type: UInt32(kODNodeTypeAuthentication))
        let query = try ODQuery.init(node: node, forRecordTypes: kODRecordTypeUsers, attribute: kODAttributeTypeRecordName, matchType: UInt32(kODMatchEqualTo), queryValues: myUser, returnAttributes: kODAttributeTypeNativeOnly, maximumResults: 0)
        let result = try query.resultsAllowingPartial(false)
        let recordRef: ODRecordRef = result[0] as! ODRecordRef
        if ODRecordChangePassword(recordRef, oldPassword as CFString!, newPassword as CFString!, nil) {
            return true
        } else {
            return false
        }
    }
    
    fileprivate func sendResetMessage() -> Void {
        myLogger.logit(.base, message:"Need to reset user's password.")
        NotificationQueue.default.enqueue(resetNotificationKey, postingStyle: .now, coalesceMask: .onName, forModes: nil)
    }
}
