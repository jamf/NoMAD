//
//  LoginWindow.swift
//  NoMAD
//
//  Created by Joel Rennich on 4/21/16.
//  Copyright © 2016 Orchard & Grove Inc. All rights reserved.
//

import Cocoa

protocol LoginWindowDelegate {
    func updateUserInfo()
}

let resetNotificationKey = Notification(name: Notification.Name(rawValue: "resetPassword"), object: nil)

class LoginWindow: NSWindowController, NSWindowDelegate, NSUserNotificationCenterDelegate {
    
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
    @IBOutlet weak var signInSpinner: NSProgressIndicator!
    @IBOutlet weak var changePasswordSpinner: NSProgressIndicator!
    
    //var noMADUser: NoMADUser? = nil
    
    @objc var suppressPasswordChange = false
    @objc var alertTimer: Timer? = nil
    
    
    @objc override var windowNibName: NSNib.Name! {
        return NSNib.Name(rawValue: "LoginWindow")
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        guard (( defaults.string(forKey: Preferences.lastUser) ) != "") else {
            self.window?.center()
            setWindowToLogin()
            return
        }
        
        changePasswordButton.title = "SignIn".translate
        self.window?.title = defaults.string(forKey: Preferences.titleSignIn) ?? "NoMAD - " + "SignIn".translate
        
        userName.stringValue = defaults.string(forKey: Preferences.lastUser)!
        Password.becomeFirstResponder()
        
        setWindowToLogin()
        self.window?.center()
        
        //if defaults.bool(forKey: Preferences.signInWindowAlert) {
            myLogger.logit(.base, message: "Setting up timer to alert on Sign In window.")
            var alertTime = 120
        if defaults.integer(forKey:Preferences.signInWindowAlertTime) != 0 {
            alertTime = defaults.integer(forKey:Preferences.signInWindowAlertTime)
        }
            alertTimer = Timer.init(timeInterval: TimeInterval(alertTime), target: self, selector: #selector(showAlert), userInfo: nil, repeats: true)
            RunLoop.main.add(alertTimer!, forMode: .commonModes)
        //}
    }
    
    func windowShouldClose(_ sender: Any) -> Bool {
        
        if defaults.bool(forKey: Preferences.signInWindowOnLaunch) && defaults.string(forKey: Preferences.lastUser) != "" {
            
            // check to ensure we're not a member of an exclusion group
            
            if !((defaults.array(forKey: Preferences.signInWindowOnLaunchExclusions)?.contains(where: { ($0 as! String)  == NSUserName() } )) ?? false ) {
                
                // move this back to the foreground
                return false
            }
        }
        return true
    }
    
    func windowWillClose(_ notification: Notification) {
        Password.stringValue = ""
        changePasswordField1.stringValue = ""
        changePasswordField2.stringValue = ""
        setWindowToLogin()
        NotificationCenter.default.post(updateNotification)
        delegate?.updateUserInfo()
        
        // clean up the timer
        
        alertTimer?.invalidate()
    }
    
    
    //When the user clicks "sign in" in NoMAD, goes through the steps
    //to login and verify that everything is correct.
    
    @IBAction func LogInClick(_ sender: Any) {
        
        // set the spinner to spinning
        
        signInSpinner.isHidden = false
        signInSpinner.startAnimation(nil)
        
        logInButton.isEnabled = false
        
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

                // Password expired, so we need to present a password change window for the user to change it.
                if (myError?.contains("Password has expired"))! {
                    defaults.set(userName.stringValue, forKey: Preferences.userPrincipal)
                    //print(userName.stringValue)
                    //print(defaults.string(forKey: "userPrincipal"))
                    let alertController = NSAlert()
                    alertController.messageText = "PasswordExpire".translate
                    alertController.addButton(withTitle: "Change Password")
                    alertController.beginSheetModal(for: self.window!, completionHandler: { [unowned self] (returnCode) -> Void in
                        if returnCode == NSApplication.ModalResponse.alertFirstButtonReturn {
                            myLogger.logit(.base, message:myError!)
                            self.setWindowToChange()
                        }
                    })
                } else if (myError?.contains("Client (" + userNameChecked + ") unknown"))! {
                    let alertController = NSAlert()
                    alertController.messageText = "InvalidUsername".translate
                    alertController.beginSheetModal(for: self.window!, completionHandler: nil)
                    signInSpinner.isHidden = true
                    signInSpinner.stopAnimation(nil)
                    logInButton.isEnabled = true
                    myLogger.logit(.base, message:myError!)
                    EXIT_FAILURE
                } else if (myError?.contains("unable to reach any KDC in realm"))! {
                    let alertController = NSAlert()
                    alertController.messageText = "NoMADMenuController-NotConnected".translate + ". Unable to reach any KDCs in your realm. You are most likely not connected to the AD domain."
                    alertController.beginSheetModal(for: self.window!, completionHandler: nil)
                    signInSpinner.isHidden = true
                    signInSpinner.stopAnimation(nil)
                    logInButton.isEnabled = true
                    myLogger.logit(.base, message:myError!)
                    EXIT_FAILURE
                } else if (myError?.contains("Password incorrect"))! {
                    let alertController = NSAlert()
                    alertController.messageText = "InvalidPassword".translate
                    alertController.beginSheetModal(for: self.window!, completionHandler: nil)
                    signInSpinner.isHidden = true
                    signInSpinner.stopAnimation(nil)
                    logInButton.isEnabled = true
                    myLogger.logit(.base, message:myError!)
                    EXIT_FAILURE
                } else {
                    // let any other random Kerb errors flow through
                    let alertController = NSAlert()
                    alertController.messageText = myError ?? "Unknown error occured."
                    alertController.beginSheetModal(for: self.window!, completionHandler: nil)
                    signInSpinner.isHidden = true
                    signInSpinner.stopAnimation(nil)
                    logInButton.isEnabled = true
                    myLogger.logit(.base, message:myError!)
                    EXIT_FAILURE
                }
                return
            }
            
            
            // Checks if console password is correct.
            let consoleUserPasswordResult = noMADUser.checkCurrentConsoleUserPassword(currentPassword)
            // Checks if keychain password is correct
            let _ = try noMADUser.checkKeychainPassword(currentPassword)
            // Check if we want to store the password in the keychain.
            let useKeychain = defaults.bool(forKey: Preferences.useKeychain)
            // Check if we want to sync the console user's password with the remote AD password.
            // Only used if console user is not AD.
            var doLocalPasswordSync = false
            
            if defaults.bool(forKey: Preferences.localPasswordSync) {
                if !suppressPasswordChange {
                    // first we assume we'll sync all passwords until we decide that we shouldn't
                    
                    doLocalPasswordSync = true
                    
                    // 1. check if this is a network user that shouldn't sync
                    
                    if let blockList = defaults.array(forKey: Preferences.localPasswordSyncDontSyncNetworkUsers) {
                        for user in blockList {
                            if user as! String == userNameChecked {
                                myLogger.logit(.debug, message: "User on network block list, not syncing password.")
                                doLocalPasswordSync = false
                            }
                        }
                    }

                    // 2. check if the local user is on a block list
                    
                    if let blocklist = defaults.array(forKey: Preferences.localPasswordSyncDontSyncLocalUsers) {
                        for user in blocklist {
                            if user as! String == NSUserName() {
                                myLogger.logit(.debug, message: "User on local block list, not syncing password.")
                                doLocalPasswordSync = false
                            }
                        }
                    }
                    
                    // 3. check for name matches
                    
                    if defaults.bool(forKey: Preferences.localPasswordSyncOnMatchOnly) {
                        // check to see if local name matches network name
                        
                        myLogger.logit(.debug, message: "Checking to see if user names match before syncing password.")
                        
                        if NSUserName() != userName.stringValue {
                            // names match let's set the sync and preflight
                            myLogger.logit(.debug, message: "User names don't match, not syncing password.")
                            doLocalPasswordSync = false
                        }
                    }
                    
                }
                
            }
            
            suppressPasswordChange = false
            
            
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
                
                myLogger.logit(LogLevel.debug, message: "Checking if keychain password needs to be changed.")
                
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
           let _ = cliTask("/usr/bin/kswitch -p " + userNameChecked )
            defaults.set(1296000, forKey: Preferences.lastPasswordWarning)
            
            if ( useKeychain ) {
                do {
                   let _ = try noMADUser.updateKeychainItem(currentPassword, newPassword2: currentPassword)
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
                
                alertController.messageText = (defaults.string(forKey: Preferences.messageLocalSync)?.replacingOccurrences(of: "\\n", with: "\n") ?? "NetworkLocalMismatch".translate)
                alertController.addButton(withTitle: "Sync")
                alertController.addButton(withTitle: "Cancel")
                //alertController.addButton(withTitle: "Sync")
                
                let localPassword = NSSecureTextField(frame: CGRect(x: 0, y: 0, width: 200, height: 24))
                alertController.accessoryView = localPassword
                
                localPassword.becomeFirstResponder()
                
                guard self.window != nil else {
                    myLogger.logit(LogLevel.debug, message: "Window does not exist.")
                    signInSpinner.isHidden = true
                    signInSpinner.stopAnimation(nil)
                    logInButton.isEnabled = true
                    // TODO: figure out if this is the proper way to handle this.
                    return
                }
                
                
                alertController.beginSheetModal(for: self.window!, completionHandler: { [unowned self] (returnCode) -> Void in
                    myLogger.logit(LogLevel.debug, message: "Sheet Modal completed")
                    if ( returnCode == NSApplication.ModalResponse.alertFirstButtonReturn ) {
                        let currentLocalPassword = localPassword.stringValue
                        let newPassword = self.Password.stringValue
                        let consoleUserPasswordResult = noMADUser.checkCurrentConsoleUserPassword(currentLocalPassword)
                        
                        // Making sure the password entered is correct,
                        // if it's not, let's exit.
                        guard ( consoleUserPasswordResult != "Invalid" ) else {
                            let alertController = NSAlert()
                            alertController.messageText = "InvalidPassword".translate
                            alertController.beginSheetModal(for: self.window!, completionHandler: nil)
                            if myError != nil {
                                myLogger.logit(.base, message:myError!)
                            }
                            myLogger.logit(.base, message:"Local password wrong.")
                            self.signInSpinner.isHidden = true
                            self.signInSpinner.stopAnimation(nil)
                            self.logInButton.isEnabled = true
                            // TODO: figure out if this is the proper way to handle this.
                            return
                        }
                        myLogger.logit(.base, message:"Local password is right. Syncing.")
                        
                        do {
                            let _ = try noMADUser.changeCurrentConsoleUserPassword(currentLocalPassword, newPassword1: newPassword, newPassword2: newPassword, forceChange: true)
                        } catch {
                            myError = "Could not change the current console user's password."
                        }
                        
                        // Check if we were able to change the local account password.
                        guard myError == nil else {
                            let alertController = NSAlert()
                            alertController.messageText = myError!
                            alertController.beginSheetModal(for: self.window!, completionHandler: nil)
                            myLogger.logit(LogLevel.debug, message:myError!)
                            self.signInSpinner.isHidden = true
                            self.signInSpinner.stopAnimation(nil)
                            self.logInButton.isEnabled = true
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
                
                
                if defaults.bool(forKey: Preferences.keychainItemsDebug) {
                    myLogger.logit(.debug, message: "Updating Keychain via Debug flag")
                    let myKeychain = KeychainUtil.init()
                    myKeychain.manageKeychainPasswords(newPassword: Password.stringValue)
                }
                
                self.Password.stringValue = ""
                signInSpinner.isHidden = true
                signInSpinner.stopAnimation(nil)
                logInButton.isEnabled = true
                self.close()
            }
        } catch let nomadUserError as NoMADUserError {
            let alertController = NSAlert()
            alertController.messageText = nomadUserError.description
            alertController.beginSheetModal(for: self.window!, completionHandler: nil)
            myLogger.logit(.base, message:myError!)
            self.Password.stringValue = ""
            signInSpinner.isHidden = true
            signInSpinner.stopAnimation(nil)
            logInButton.isEnabled = true
            self.close()
        } catch {
            let alertController = NSAlert()
            alertController.messageText = "Unknown error."
            alertController.beginSheetModal(for: self.window!, completionHandler: nil)
            myLogger.logit(.base, message:myError!)
            self.Password.stringValue = ""
            signInSpinner.isHidden = true
            signInSpinner.stopAnimation(nil)
            logInButton.isEnabled = true
            self.close()
        }
        
        // fire off the SignInCommand script if there is one
        
        if defaults.string(forKey: Preferences.signInCommand) != "" {
            let myResult = cliTask(defaults.string(forKey: Preferences.signInCommand)!)
            myLogger.logit(LogLevel.base, message: myResult)
        }
        
        signInSpinner.isHidden = true
        signInSpinner.stopAnimation(nil)
        logInButton.isEnabled = true
        
        // DO NOT put self.close() here to try to save code,
        // it will mess up the local password sync code.
    }
    
    @IBAction func changePasswordButtonClick(_ sender: AnyObject) {
        
        changePasswordSpinner.isHidden = false
        changePasswordSpinner.startAnimation(nil)
        changePasswordButton.isEnabled = false
        
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
            
            // treat no local sync as a soft error for now
            // TODO: handle edge case of 1. not bound, 2. local password sync, 3. first login
            
            var destroyTickets = false
            
            if myError != "" && !myError.contains("does not match console user") {
                let alertController = NSAlert()
                alertController.messageText = myError
                
                alertController.beginSheetModal(for: self.window!, completionHandler: nil)
                changePasswordSpinner.isHidden = true
                changePasswordSpinner.stopAnimation(nil)
                changePasswordButton.isEnabled = true
            } else {
                let alertController = NSAlert()
                alertController.messageText = "PasswordChangeSuccessful".translate
                
                if myError.contains("does not match console user") {
                    alertController.messageText = "Local password not in sync, please try signing in again again to sync local password now that AD password is updated."
                    destroyTickets = true
                }
                
                alertController.beginSheetModal(for: self.window!, completionHandler: {( response ) in
                    if ( response == 0 ) && !destroyTickets {
                        
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
                        self.changePasswordSpinner.isHidden = true
                        self.changePasswordSpinner.stopAnimation(nil)
                        self.changePasswordButton.isEnabled = true
                        
                        self.setWindowToLogin()
                        self.close()
                    } else {
                        self.changePasswordSpinner.isHidden = true
                        self.changePasswordSpinner.stopAnimation(nil)
                        self.changePasswordButton.isEnabled = true
                        
                        self.setWindowToLogin()
                        self.close()
                    }
                })
            }
            myLogger.logit(.base, message:myError)
        } else {
            changePasswordSpinner.isHidden = true
            changePasswordSpinner.stopAnimation(nil)
            changePasswordButton.isEnabled = true
            
            let alertController = NSAlert()
            alertController.messageText = "PasswordMismatch".translate
            alertController.beginSheetModal(for: self.window!, completionHandler: nil)

            
        }
        
        // fire off the SignInCommand script if there is one
        
        changePasswordSpinner.isHidden = true
        changePasswordSpinner.stopAnimation(nil)
        changePasswordButton.isEnabled = true
        
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
        
        passwordLabel.stringValue = "LoginWindow-PasswordLabel".translate
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
        signInSpinner.stopAnimation(nil)
        signInSpinner.isHidden = true
        
        changePasswordField1.isHidden = false
        changePasswordField2.isHidden = false
        newPasswordLable.isHidden = false
        newPasswordLabel2.isHidden = false
        
        // enable the good things
        
        logInButton.isHidden = true
        logInButton.isEnabled = false
        
        passwordLabel.stringValue = "LoginWindow-OldPasswordLabel".translate
        
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
    
    @objc fileprivate func showAlert() {
        
        myLogger.logit(.debug, message: "Building Sign In window alert.")
        let notification = NSUserNotification()
        notification.title = "Sign In"
        notification.informativeText = "Please sign in with your network account."
        notification.hasActionButton = false
        
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    fileprivate func showNotification(_ title: String, text: String, date: Date, action: String) -> Void {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = text
        //notification.deliveryDate = date
        if action != "" {
            //notification.hasActionButton = true
            //notification.actionButtonTitle = action
        }
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    // user notification center callbacks
    
    func userNotificationCenter(_ center: NSUserNotificationCenter, didDeliver notification: NSUserNotification) {
        //implementation
        return
    }
    
    func userNotificationCenter(_ center: NSUserNotificationCenter, didActivate notification: NSUserNotification) {
        self.window?.forceToFrontAndFocus(nil)
        return
    }
}
