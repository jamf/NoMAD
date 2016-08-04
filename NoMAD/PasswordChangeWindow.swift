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

class PasswordChangeWindow: NSWindowController, NSWindowDelegate {
    
    var delegate: PasswordChangeDelegate?
    
    @IBOutlet weak var newPassword: NSSecureTextField!
    @IBOutlet weak var oldPassword: NSSecureTextField!
    @IBOutlet weak var newPasswordAgain: NSSecureTextField!
    
    override var windowNibName: String! {
        return "PasswordChangeWindow"
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        self.window?.center()
        self.window?.makeKeyAndOrderFront(nil)
        NSApp.activateIgnoringOtherApps(true)
        
        // blank out the password fields
        oldPassword.stringValue = ""
        newPassword.stringValue = ""
        newPasswordAgain.stringValue = ""
        
    }
    
    func windowWillClose(notification: NSNotification) {
        delegate?.updateUserInfo()
    }
	
    @IBAction func changePasswordClicked(sender: AnyObject) {
		let userPrincipal = defaults.stringForKey("userPrincipal")!.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
		let currentPassword = oldPassword.stringValue
		let newPassword1 = newPassword.stringValue
		let newPassword2 = newPasswordAgain.stringValue
		
        // If the user entered the same value for both password fields.
        if ( newPassword1 == newPassword2) {
			var myError = ""
			
			myError = performPasswordChange(userPrincipal, currentPassword: currentPassword, newPassword1: newPassword1, newPassword2: newPassword2)
		/*
		var myError = ""
		if ( newPassword.stringValue == newPasswordAgain.stringValue) {
			
			// Let's try changing the password with Kerberos
            let ChangePassword: KerbUtil = KerbUtil()
            print(defaults.stringForKey("userPrincipal")!)
            myError = ChangePassword.changeKerbPassword(oldPassword.stringValue, newPassword.stringValue, defaults.stringForKey("userPrincipal")!.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()))
			
			// If there wasn't an error and Sync Local Password is set
			// Check if the old password entered matches the current local password
            if (defaults.integerForKey("LocalPasswordSync") == 1 ) && myError == "" {
                do { try testLocalPassword(oldPassword.stringValue) }
                    catch {
                        NSLog("Local password check Swift = no")
                        myError = "Your current local password does not match your AD password."
                    }
            }
			
			// If there wasn't an error and Sync Local Password is set
			// Update the keychain password
            if (defaults.integerForKey("LocalPasswordSync") == 1 ) && myError == "" {
                // synch keychain
                if (ChangePassword.changeKeychainPassword(oldPassword.stringValue, newPassword.stringValue) == 0) {
                    NSLog("Error changing local keychain")
                    myError = "Could not change your local keychain password."
                }
            }
<<<<<<< Updated upstream
            
=======
			
			// If there wasn't an error and Sync Local Password is set
			// Update the local password
>>>>>>> Stashed changes
            if (defaults.stringForKey("LocalPasswordSync") != "" ) && myError == "" {
                // synch local passwords
                do { try changeLocalPassword( oldPassword.stringValue, newPassword: newPassword.stringValue) }
                catch {
                    NSLog("Local password change failed")
                    myError = "Local password change failed"
                }
            }
			*/
			// IF there were any errors, display the error message as an alert.
			// ELSE let the user know that the expiration time may take a little bit.
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
                        self.close()
                    } else {
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
			print(username)
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
            print("Password changed!")
            return true
        } else {
            return false
        }

    }
    
}
