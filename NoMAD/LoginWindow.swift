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
        guard (( defaults.string(forKey: "LastUser") ) != nil) else {
            self.window?.center()
            setWindowToLogin()
            return
        }
        
        changePasswordButton.title = "NoMADMenuController-LogIn".translate
        self.window?.title = "NoMAD - " + "NoMADMenuController-LogIn".translate
        
        userName.stringValue = defaults.string(forKey: "LastUser")! ?? ""
        Password.becomeFirstResponder()
        
        setWindowToLogin()
        
        self.window?.center()

    }
    
    func windowWillClose(_ notification: Notification) {
        Password.stringValue = ""
        changePasswordField1.stringValue = ""
        changePasswordField2.stringValue = ""
        
        notificationCenter.post(notificationKey)
        delegate?.updateUserInfo()
    }
    
    @IBAction func LogInClick(_ sender: AnyObject) {
        
        var userNameChecked = ""
        
        if userName.stringValue.contains("@") {
            userNameChecked = userName.stringValue
        } else {
            userNameChecked = userName.stringValue + "@" + defaults.string(forKey: "KerberosRealm")!
        }
        
        //let GetCredentials: KerbUtil = KerbUtil()
        var myError: String? = ""
        
        myError = GetCredentials.getKerbCredentials( Password.stringValue, userNameChecked )
        
        // make sure the just logged in user is the current user and then reset the password warning
        
        if myError == nil {
            cliTask("/usr/bin/kswitch -p " + userNameChecked )
            defaults.set(1296000, forKey: "LastPasswordWarning")
        }
        
        // put password in keychain, but only if there was no error
        
        if ( defaults.bool(forKey: "UseKeychain") && myError == nil ) {
            
            // check if keychain item exists and delete it if it does
            
            let myKeychainUtil = KeychainUtil()
            
            myKeychainUtil.findAndDelete(userNameChecked)
            
            myKeychainUtil.setPassword(userNameChecked, pass: Password.stringValue)
            
        }
        
        if ( myError == nil  && defaults.integer(forKey: "LocalPasswordSync") == 1 ) {
            do { try testLocalPassword( Password.stringValue) }
            catch {
                
                myLogger.logit(0, message:"Local password check failed. Attempting to sync.")
                let alertController = NSAlert()
                alertController.messageText = "Your network and local passwords are not the same. Please enter the password for your Mac."
                alertController.addButton(withTitle: "Cancel")
                alertController.addButton(withTitle: "Sync")
                
                let localPassword = NSSecureTextField(frame: CGRect(x: 0, y: 0, width: 200, height: 24))
                alertController.accessoryView = localPassword
                alertController.beginSheetModal(for: self.window!, completionHandler: { (response) -> Void in
                    if response == 1001 {
                        do { try self.testLocalPassword(localPassword.stringValue)
                            myLogger.logit(0, message:"Local password is right. Syncing.")
                            if (GetCredentials.changeKeychainPassword(self.Password.stringValue, localPassword.stringValue) == 0) {
                                myLogger.logit(0, message:"Error changing local keychain")
                                myError = "Could not change your local keychain password."
                            }
                            do { try self.changeLocalPassword( localPassword.stringValue, newPassword: self.Password.stringValue) }
                            catch {
                                myLogger.logit(0, message:"Local password change failed")
                                myError = "Local password change failed"
                            }
                        }
                        catch {
                            let alertController = NSAlert()
                            alertController.messageText = "Invalid password. Please try again."
                            alertController.beginSheetModal(for: self.window!, completionHandler: nil)
                            myLogger.logit(0, message:myError!)
                            EXIT_FAILURE
                            myLogger.logit(0, message:"Local password wrong.")
                        }
                    } else {
                        myLogger.logit(0, message:"Local sync cancelled by user.")
                        self.Password.stringValue = ""
                        self.close()
                    }
                    self.Password.stringValue = ""
                    self.close()
                })
				
				let localPassword = NSSecureTextField(frame: CGRectMake(0, 0, 200, 24))
				alertController.accessoryView = localPassword
				guard self.window != nil else {
					myLogger.logit(LogLevel.debug, message: "Window does not exist.")
					EXIT_FAILURE
					// TODO: figure out if this is the proper way to handle this.
					return
				}
				
				
				alertController.beginSheetModalForWindow(self.window!, completionHandler: { [unowned self] (returnCode) -> Void in
					myLogger.logit(LogLevel.debug, message: "Sheet Modal completed")
					if ( returnCode == NSAlertSecondButtonReturn ) {
						let currentLocalPassword = localPassword.stringValue
						let newPassword = self.Password.stringValue
						let localPasswordIsCorrect = noMADUser.checkCurrentConsoleUserPassword(currentLocalPassword)
						
						// Making sure the password entered is correct,
						// if it's not, let's exit.
						guard localPasswordIsCorrect else {
							let alertController = NSAlert()
							alertController.messageText = "Invalid password. Please try again."
							alertController.beginSheetModalForWindow(self.window!, completionHandler: nil)
							myLogger.logit(0, message:myError!)
							myLogger.logit(0, message:"Local password wrong.")
							EXIT_FAILURE
							// TODO: figure out if this is the proper way to handle this.
							return
						}
						myLogger.logit(0, message:"Local password is right. Syncing.")
						
						do {
							try noMADUser.changeCurrentConsoleUserPassword(currentLocalPassword, newPassword1: newPassword, newPassword2: newPassword, forceChange: true)
						} catch {
							myError = "Could not change the current console user's password."
						}
						// Check if we were able to change the local account password.
						guard myError == nil else {
							let alertController = NSAlert()
							alertController.messageText = myError!
							alertController.beginSheetModalForWindow(self.window!, completionHandler: nil)
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
					} else {
						myLogger.logit(0, message:"Local sync cancelled by user.")
					}
				})
				
			} else {
				myLogger.logit(LogLevel.info, message: "Not syncing local account because: ")
				if consoleUserPasswordIsCorrect {
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
			alertController.beginSheetModalForWindow(self.window!, completionHandler: nil)
			myLogger.logit(0, message:myError!)
			EXIT_FAILURE
			self.Password.stringValue = ""
			self.close()
        } else {
            
            if defaults.integer(forKey: "Verbose") >= 1 {
                myLogger.logit(0, message:"Logging in as: " + userName.stringValue)
            }
            
            if myError == "Password has expired" {
                defaults.set(userName.stringValue, forKey: "userPrincipal")
                print(userName.stringValue)
                print(defaults.string(forKey: "userPrincipal"))
                let alertController = NSAlert()
                alertController.messageText = "Your password has expired. Please reset your password now."
                alertController.addButton(withTitle: "Change Password")
                alertController.beginSheetModal(for: self.window!, completionHandler: { [ unowned self ] (returnCode) -> Void in
                    if returnCode == NSAlertFirstButtonReturn {
                        myLogger.logit(0, message:myError!)
                        self.setWindowToChange()
                        
                    }
                    })
            }
            
            if myError != nil && myError != "Password has expired" {
                let alertController = NSAlert()
                alertController.messageText = "Invalid password. Please try again."
                alertController.beginSheetModal(for: self.window!, completionHandler: nil)
                myLogger.logit(0, message:myError!)
                EXIT_FAILURE
            } else if myError == nil {
                Password.stringValue = ""
                self.close()
            }
        }
    }
    
    @IBAction func changePasswordButtonClick(_ sender: AnyObject) {
        let userPrincipal: String
        if userName.stringValue.contains("@") {
            userPrincipal = userName.stringValue
        } else {
            userPrincipal = userName.stringValue + "@" + defaults.string(forKey: "KerberosRealm")!
        }
        let currentPassword = Password.stringValue
        let newPassword1 = changePasswordField1.stringValue
        let newPassword2 = changePasswordField2.stringValue
        
        // If the user entered the same value for both password fields.
        if ( newPassword1 == newPassword2) {
            var myError = ""
            myError = performPasswordChange(userPrincipal, currentPassword: currentPassword, newPassword1: newPassword1, newPassword2: newPassword2)
            
            // put password in keychain, but only if there was no error
            
            if ( defaults.bool(forKey: "UseKeychain") && myError != "" ) {
                
                // check if keychain item exists and delete it if it does
                
                let myKeychainUtil = KeychainUtil()
                
                myKeychainUtil.findAndDelete(userName.stringValue + "@" + defaults.string(forKey: "KerberosRealm")!)
                
                myKeychainUtil.setPassword(userName.stringValue + "@" + defaults.string(forKey: "KerberosRealm")!, pass: Password.stringValue)
                
            }
            
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
                                myError = GetCredentials.getKerbCredentials( newPassword1, (userPrincipal + "@" + defaults.string(forKey: "KerberosRealm")!))
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
            myLogger.logit(0, message:myError)
        } else {
            
            let alertController = NSAlert()
            alertController.messageText = "New passwords don't match!"
            alertController.beginSheetModal(for: self.window!, completionHandler: nil)
            EXIT_FAILURE
            
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
        
        self.window?.setContentSize(changeSize)
        
    }
    
    // username must be of the format username@kerberosRealm
    func performPasswordChange(_ username: String, currentPassword: String, newPassword1: String, newPassword2: String) -> String {
        let localPasswordSync = defaults.integer(forKey: "LocalPasswordSync")
        var myError: String = ""
        
        if (currentPassword.isEmpty || newPassword1.isEmpty || newPassword2.isEmpty) {
            myLogger.logit(0, message:"Some of the fields are empty")
            myError = "All fields must be filled in"
            return myError
        } else {
            myLogger.logit(2, message:"All fields are filled in, continuing")
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
                    myLogger.logit(1, message:"Local password check Swift = no")
                    myError = "Your current local password does not match your AD password."
                }
            }
            
            // update the password in the keychain if we're using it
            
            if ( defaults.bool(forKey: "UseKeychain") ) {
                
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
                    myLogger.logit(1, message:"Error changing local keychain")
                    myError = "Could not change your local keychain password."
                }
            }
            
            // If there wasn't an error and Sync Local Password is set
            // Update the local password
            if (localPasswordSync == 1 ) && myError == "" {
                do { try changeLocalPassword( currentPassword, newPassword: newPassword1) }
                catch {
                    myLogger.logit(0, message:"Local password change failed")
                    myError = "Local password change failed"
                }
            }
        }
        return myError
    }
    
    fileprivate func testLocalPassword(_ password: String) throws {
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
        myLogger.logit(0, message:"Need to reset user's password.")
        notificationQueue.enqueue(resetNotificationKey, postingStyle: .now, coalesceMask: .onName, forModes: nil)
    }
}
