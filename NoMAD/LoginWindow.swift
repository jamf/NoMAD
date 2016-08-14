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

let resetNotificationKey = NSNotification(name: "resetPassword", object: nil)

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
    
    
    override var windowNibName: String! {
        return "LoginWindow"
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        guard (( defaults.stringForKey("LastUser") ) != nil) else {
            self.window?.center()
            self.window?.makeKeyAndOrderFront(nil)
            NSApp.activateIgnoringOtherApps(true)
            setWindowToLogin()
            return
        }
        
        userName.stringValue = defaults.stringForKey("LastUser")! ?? ""
        Password.becomeFirstResponder()
        
        setWindowToLogin()
        
        self.window?.center()
        self.window?.makeKeyAndOrderFront(nil)
        NSApp.activateIgnoringOtherApps(true)
    }
    
    func windowWillClose(notification: NSNotification) {
        Password.stringValue = ""
        changePasswordField1.stringValue = ""
        changePasswordField2.stringValue = ""
        
        notificationCenter.postNotification(notificationKey)
        delegate?.updateUserInfo()
        
    }
    
    @IBAction func LogInClick(sender: AnyObject) {
        
        
        let GetCredentials: KerbUtil = KerbUtil()
        var myError: String? = ""
        
        if myError == "" {
            if userName.stringValue.containsString("@") {
                myError = GetCredentials.getKerbCredentials( Password.stringValue, userName.stringValue );
            } else {
                myError = GetCredentials.getKerbCredentials(Password.stringValue, (userName.stringValue + "@" + defaults.stringForKey("KerberosRealm")!))
            }
        }
        
        // put password in keychain
        
        if ( defaults.boolForKey("UseKeychain") ) {
            // check if keychain item exists
            
            let myKeychainUtil = KeychainUtil()
            
            do { try myKeychainUtil.findPassword(userName.stringValue + "@" + defaults.stringForKey("KerberosRealm")!) } catch {
                myKeychainUtil.setPassword(userName.stringValue + "@" + defaults.stringForKey("KerberosRealm")!, pass: Password.stringValue)
            }
            
        }
        
        if ( myError == nil  && defaults.integerForKey("LocalPasswordSync") == 1 ) {
            do { try testLocalPassword( Password.stringValue) }
            catch {
                myError = "Attempting local password sync."
                NSLog("Local password check failed. Attempting to sync.")
                let alertController = NSAlert()
                alertController.messageText = "Your network and local passwords are not the same. Please enter the password for your Mac."
                alertController.addButtonWithTitle("Cancel")
                alertController.addButtonWithTitle("Sync")
                let localPassword = NSSecureTextField(frame: CGRectMake(0, 0, 200, 24))
                alertController.accessoryView = localPassword
                alertController.beginSheetModalForWindow(self.window!, completionHandler: { (response) -> Void in
                    if response == 1001 {
                        do { try self.testLocalPassword(localPassword.stringValue)
                            NSLog("Local password is right. Syncing.")
                            if (GetCredentials.changeKeychainPassword(self.Password.stringValue, localPassword.stringValue) == 0) {
                                NSLog("Error changing local keychain")
                                myError = "Could not change your local keychain password."
                            }
                            do { try self.changeLocalPassword( localPassword.stringValue, newPassword: self.Password.stringValue) }
                            catch {
                                NSLog("Local password change failed")
                                myError = "Local password change failed"
                            }
                        }
                        catch {
                            let alertController = NSAlert()
                            alertController.messageText = "Invalid password. Please try again."
                            alertController.beginSheetModalForWindow(self.window!, completionHandler: nil)
                            NSLog(myError!)
                            EXIT_FAILURE
                            NSLog("Local password wrong.")
                        }
                    } else {
                        NSLog("Local sync cancelled by user.")
                        self.Password.stringValue = ""
                        self.close()
                    }
                    self.Password.stringValue = ""
                    self.close()
                })
                
            }
        } else {
            
            if defaults.integerForKey("Verbose") >= 1 {
                NSLog("Logging in as: " + userName.stringValue)
            }
            
            if myError == "Password has expired" {
                defaults.setObject(userName.stringValue, forKey: "userPrincipal")
                print(userName.stringValue)
                print(defaults.stringForKey("userPrincipal"))
                let alertController = NSAlert()
                alertController.messageText = "Your password has expired. Please reset your password now."
                alertController.addButtonWithTitle("Change Password")
                alertController.beginSheetModalForWindow(self.window!, completionHandler: { [ unowned self ] (returnCode) -> Void in
                    if returnCode == NSAlertFirstButtonReturn {
                        NSLog(myError!)
                        self.setWindowToChange()
                        
                    }
                    })
            }
            
            if myError != nil && myError != "Password has expired" {
                let alertController = NSAlert()
                alertController.messageText = "Invalid password. Please try again."
                alertController.beginSheetModalForWindow(self.window!, completionHandler: nil)
                NSLog(myError!)
                EXIT_FAILURE
            } else if myError == nil {
                Password.stringValue = ""
                self.close()
            }
        }
    }
    
    @IBAction func changePasswordButtonClick(sender: AnyObject) {
        let userPrincipal: String
        if userName.stringValue.containsString("@") {
            userPrincipal = userName.stringValue
        } else {
            userPrincipal = userName.stringValue + "@" + defaults.stringForKey("KerberosRealm")!
        }
        let currentPassword = Password.stringValue
        let newPassword1 = changePasswordField1.stringValue
        let newPassword2 = changePasswordField2.stringValue
        
        // If the user entered the same value for both password fields.
        if ( newPassword1 == newPassword2) {
            var myError = ""
            myError = performPasswordChange(userPrincipal, currentPassword: currentPassword, newPassword1: newPassword1, newPassword2: newPassword2)
            
            if myError != "" {
                let alertController = NSAlert()
                alertController.messageText = myError
                alertController.beginSheetModalForWindow(self.window!, completionHandler: nil)
                EXIT_FAILURE
            } else {
                let alertController = NSAlert()
                alertController.messageText = "Password changed successfully. Note: it may take up to an hour for your password expiration time to be updated."
                
                alertController.beginSheetModalForWindow(self.window!, completionHandler: {( response ) in
                    if ( response == 0 ) {
                        
                        // login via kinit here with the new password
                        
                        let GetCredentials: KerbUtil = KerbUtil()
                        var myError: String? = ""
                        
                        if myError == "" {
                            if userPrincipal.containsString("@") {
                                myError = GetCredentials.getKerbCredentials( newPassword1, userPrincipal );
                            } else {
                                myError = GetCredentials.getKerbCredentials( newPassword1, (userPrincipal + "@" + defaults.stringForKey("KerberosRealm")!))
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
            NSLog(myError)
        } else {
            
            let alertController = NSAlert()
            alertController.messageText = "New passwords don't match!"
            alertController.beginSheetModalForWindow(self.window!, completionHandler: nil)
            EXIT_FAILURE
            
        }
    }
    
    private func setWindowToLogin() {
        
        // set the size
        
        var loginSize = NSSize()
        loginSize.width = 381
        loginSize.height = 114
        
        // disable the bad things
        
        changePasswordButton.hidden = true
        changePasswordButton.enabled = false
        
        changePasswordField1.hidden = true
        changePasswordField2.hidden = true
        newPasswordLable.hidden = true
        newPasswordLabel2.hidden = true
        
        // enable the good things
        
        logInButton.hidden = false
        logInButton.enabled = true
        
        passwordLabel.stringValue = "Password"
        Password.stringValue = ""
        
        self.window?.setContentSize(loginSize)
        
    }
    
    private func setWindowToChange() {
        
        // set the size
        
        var changeSize = NSSize()
        changeSize.width = 381
        changeSize.height = 178
        
        // disable the bad things
        
        changePasswordButton.hidden = false
        changePasswordButton.enabled = true
        
        changePasswordField1.hidden = false
        changePasswordField2.hidden = false
        newPasswordLable.hidden = false
        newPasswordLabel2.hidden = false
        
        // enable the good things
        
        logInButton.hidden = true
        logInButton.enabled = false
        
        passwordLabel.stringValue = "Old Password"
        
        self.window?.setContentSize(changeSize)
        
    }
    
    // username must be of the format username@kerberosRealm
    func performPasswordChange(username: String, currentPassword: String, newPassword1: String, newPassword2: String) -> String {
        let localPasswordSync = defaults.integerForKey("LocalPasswordSync")
        var myError: String = ""
        
        if (currentPassword.isEmpty || newPassword1.isEmpty || newPassword2.isEmpty) {
            NSLog ("Some of the fields are empty")
            myError = "All fields must be filled in"
            return myError
        } else {
            NSLog("All fields are filled in, continuing")
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
                    NSLog("Local password check Swift = no")
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
                    NSLog("Error changing local keychain")
                    myError = "Could not change your local keychain password."
                }
            }
            
            // If there wasn't an error and Sync Local Password is set
            // Update the local password
            if (localPasswordSync == 1 ) && myError == "" {
                do { try changeLocalPassword( currentPassword, newPassword: newPassword1) }
                catch {
                    NSLog("Local password change failed")
                    myError = "Local password change failed"
                }
            }
        }
        return myError
    }
    
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
        let result = try query.resultsAllowingPartial(false)
        let recordRef: ODRecordRef = result[0] as! ODRecordRef
        if ODRecordChangePassword(recordRef, oldPassword, newPassword, nil) {
            return true
        } else {
            return false
        }
    }
    
    private func sendResetMessage() -> Void {
        NSLog("Need to reset user's password.")
        notificationQueue.enqueueNotification(resetNotificationKey, postingStyle: .PostNow, coalesceMask: .CoalescingOnName, forModes: nil)
    }
}
