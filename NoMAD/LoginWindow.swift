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
	
	//var noMADUser: NoMADUser? = nil
    
    
    override var windowNibName: String! {
        return "LoginWindow"
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        guard (( defaults.stringForKey("LastUser") ) != nil) else {
            self.window?.center()
            setWindowToLogin()
            return
        }
        
        changePasswordButton.title = "NoMADMenuController-LogIn".translate
        self.window?.title = "NoMAD - " + "NoMADMenuController-LogIn".translate
        
        userName.stringValue = defaults.stringForKey("LastUser")! ?? ""
        Password.becomeFirstResponder()
        
        setWindowToLogin()
        
        self.window?.center()

    }
    
    func windowWillClose(notification: NSNotification) {
        Password.stringValue = ""
        changePasswordField1.stringValue = ""
        changePasswordField2.stringValue = ""
        
        notificationCenter.postNotification(notificationKey)
        delegate?.updateUserInfo()
    }
	
	/**
	When the user clicks "sign in" in NoMAD, goes through the steps 
	to login and verify that everything is correct.
	
	*/
    @IBAction func LogInClick(sender: AnyObject) {
        
        var userNameChecked = ""
        
        if userName.stringValue.containsString("@") {
            userNameChecked = userName.stringValue
        } else {
            userNameChecked = userName.stringValue + "@" + defaults.stringForKey("KerberosRealm")!
        }
        
        //let GetCredentials: KerbUtil = KerbUtil()
        var myError: String? = ""
		let currentPassword = Password.stringValue
		
		do {
			let noMADUser = try NoMADUser(kerberosPrincipal: userNameChecked)
			
			// Checks if the remote users's password is correct.
			// If it is and the current console user is not an
			// AD account, then we'll change it.
			myError = noMADUser.checkRemoteUserPassword(currentPassword)
			
			// Let's present any errors we got before we do anything else.
			// We're using guard to check if myError is the correct value
			// because we want to force it to return otherwise.
			guard myError == nil else {
				switch myError! {
				// Password expired, so we need to present a password change window for the user to change it.
				case "Password has expired":
					defaults.setObject(userName.stringValue, forKey: "userPrincipal")
					print(userName.stringValue)
					print(defaults.stringForKey("userPrincipal"))
					let alertController = NSAlert()
					alertController.messageText = "Your password has expired. Please reset your password now."
					alertController.addButtonWithTitle("Change Password")
					alertController.beginSheetModalForWindow(self.window!, completionHandler: { [ unowned self ] (returnCode) -> Void in
						if returnCode == NSAlertFirstButtonReturn {
							myLogger.logit(0, message:myError!)
							self.setWindowToChange()
						}
					})
				case "Client (" + userNameChecked + ") unknown":
					let alertController = NSAlert()
					alertController.messageText = "Invalid username. Please try again."
					alertController.beginSheetModalForWindow(self.window!, completionHandler: nil)
					myLogger.logit(0, message:myError!)
					EXIT_FAILURE
				//
				default:
					let alertController = NSAlert()
					alertController.messageText = "Invalid password. Please try again."
					alertController.beginSheetModalForWindow(self.window!, completionHandler: nil)
					myLogger.logit(0, message:myError!)
					EXIT_FAILURE
				}
				// TODO: figure out if this is the proper way to handle this.
				return
			}
			
			
			// Checks if console password is correct.
			let consoleUserPasswordIsCorrect = noMADUser.checkCurrentConsoleUserPassword(currentPassword)
			// Checks if keychain password is correct
			let keychainPasswordIsCorrect = try noMADUser.checkKeychainPassword(currentPassword)
			// Check if we want to store the password in the keychain.
			let useKeychain = defaults.boolForKey("UseKeychain")
			// Check if we want to sync the console user's password with the remote AD password.
			// Only used if console user is not AD.
			var doLocalPasswordSync = false
			if defaults.integerForKey("LocalPasswordSync") == 1 {
				doLocalPasswordSync = true
			}
			
			let consoleUserIsAD = noMADUser.currentConsoleUserIsADuser()
			
			
			// make sure the just logged in user is the current user and then reset the password warning
			// TODO: @mactroll - why is this 1296000?
			cliTask("/usr/bin/kswitch -p " + userNameChecked )
			defaults.setInteger(1296000, forKey: "LastPasswordWarning")
			
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
			if !consoleUserPasswordIsCorrect && doLocalPasswordSync && !consoleUserIsAD {
				myLogger.logit(LogLevel.debug, message:"Local user's password does not match remote user.")
				myLogger.logit(LogLevel.debug, message:"Local Sync is enabled.")
				myLogger.logit(LogLevel.debug, message:"Console user is not an AD account.")
				myLogger.logit(LogLevel.debug, message:"Lets try to sync the passwords, prompting user.")
				let alertController = NSAlert()
				// TODO: replace with localized text
				alertController.messageText = "Your network and local passwords are not the same. Please enter the password for your Mac."
				alertController.addButtonWithTitle("Cancel")
				alertController.addButtonWithTitle("Sync")
				
				let localPassword = NSSecureTextField(frame: CGRectMake(0, 0, 200, 24))
				alertController.accessoryView = localPassword
				alertController.beginSheetModalForWindow(self.window!, completionHandler: {
					(response) -> Void in
					// TODO: @mactroll: what is 1001? 
					// I see "NSModalResponseStop" which is supposedly the default 
					// and "NSModalResponseAbort" which I assume is what happens when someone presses cancel.
					if response == 1001 {
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
							EXIT_FAILURE
							myLogger.logit(0, message:"Local password wrong.")
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
						guard myError != nil else {
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
			}
		} catch let nomadUserError as NoMADUserError {
			let alertController = NSAlert()
			alertController.messageText = nomadUserError.description
			alertController.beginSheetModalForWindow(self.window!, completionHandler: nil)
			myLogger.logit(0, message:myError!)
			EXIT_FAILURE
		} catch {
			let alertController = NSAlert()
			alertController.messageText = "Unknown error."
			alertController.beginSheetModalForWindow(self.window!, completionHandler: nil)
			myLogger.logit(0, message:myError!)
			EXIT_FAILURE
		}
		
		// And we finished the login, so let's close the window.
		self.Password.stringValue = ""
		self.close()
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
            myLogger.logit(0, message:myError)
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
	/*
    func performPasswordChange(username: String, currentPassword: String, newPassword1: String, newPassword2: String) -> String {
        let localPasswordSync = defaults.integerForKey("LocalPasswordSync")
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
	*/
    // TODO: Clean this up.
    private func testLocalPassword(password: String) throws {
        let myUser = NSUserName()
        let session = ODSession.defaultSession()
        let node = try ODNode.init(session: session, type: UInt32(kODNodeTypeAuthentication))
        let query = try ODQuery.init(node: node, forRecordTypes: kODRecordTypeUsers, attribute: kODAttributeTypeRecordName, matchType: UInt32(kODMatchEqualTo), queryValues: myUser, returnAttributes: kODAttributeTypeNativeOnly, maximumResults: 0)
        let result = try query.resultsAllowingPartial(false)
        let record: ODRecord = result[0] as! ODRecord
        try record.verifyPassword(password)
    }
	
	// TODO: Clean this up.
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
        myLogger.logit(0, message:"Need to reset user's password.")
        notificationQueue.enqueueNotification(resetNotificationKey, postingStyle: .PostNow, coalesceMask: .CoalescingOnName, forModes: nil)
    }
}
