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
		// blank out the password fields
		oldPassword.stringValue = ""
		newPassword.stringValue = ""
		newPasswordAgain.stringValue = ""
		
		// Update the Menubar info.
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
            
            // put password in keychain, but only if there was no error
            
            if ( defaults.boolForKey("UseKeychain") && myError != "" ) {
                
                // check if keychain item exists and delete it if it does
                
                let myKeychainUtil = KeychainUtil()
                
                myKeychainUtil.findAndDelete(userPrincipal)
                
                myKeychainUtil.setPassword(userPrincipal, pass: newPassword1)
            }
            
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
            myLogger.logit(0, message: myError)
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
            myLogger.logit(1, message: "Some of the fields are empty")
			myError = "All fields must be filled in"
			return myError
		} else {
			myLogger.logit(1, message: "All fields are filled in, continuing")
		}
		// If the user entered the same value for both password fields.
		if ( newPassword1 == newPassword2 ) {
			let ChangePassword: KerbUtil = KerbUtil()
            myLogger.logit(0, message: "Change password for " + username )
            
            // check to see we can match the kpasswd server with the LDAP server
            
            let kerbPrefFile = checkKpasswdServer(true)
            
			myError = ChangePassword.changeKerbPassword(currentPassword, newPassword1, username)
            
            
            if ( defaults.boolForKey("UseKeychain") ) {
                // check if keychain item exists
                
                let myKeychainUtil = KeychainUtil()
                
                do { try myKeychainUtil.findPassword(username) } catch {
                    myKeychainUtil.setPassword(username, pass: newPassword1)
                }
                
            }
			// If there wasn't an error and Sync Local Password is set
			// Check if the old password entered matches the current local password
			if (localPasswordSync == 1 ) && myError == "" {
				do { try testLocalPassword(currentPassword) }
				catch {
					myLogger.logit(1, message: "Local password check Swift = no")
					myError = "Your current local password does not match your AD password."
				}
			}
            
            if kerbPrefFile {
                cliTask("/usr/bin/defaults delete com.apple.Kerberos")
            }
			
			// If there wasn't an error and Sync Local Password is set
			// Update the keychain password
			if (localPasswordSync == 1 ) && myError == "" {
				if (ChangePassword.changeKeychainPassword(currentPassword, newPassword1) == 0) {
					myLogger.logit(0, message: "Error changing local keychain")
					myError = "Could not change your local keychain password."
				}
			}
			
			// If there wasn't an error and Sync Local Password is set
			// Update the local password
			if (localPasswordSync == 1 ) && myError == "" {
				do { try changeLocalPassword( currentPassword, newPassword: newPassword1) }
				catch {
					myLogger.logit(0, message: "Local password change failed")
					myError = "Local password change failed"
				}
			}
		} else {
			myError = "New passwords don't match."
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
    
    // write out local krb5.conf file to ensure password change happens to the same kdc as we're using for LDAP
    
    private func checkKpasswdServer(writePref: Bool ) -> Bool {
        let myKpasswdServers = cliTask("/usr/bin/dig +short -t SRV _kpasswd._tcp." + defaults.stringForKey("ADDomain")!)
        
        if myKpasswdServers.containsString(defaults.stringForKey("CurrentLDAPServer")!) {
            
            if writePref {
                // check to see if a file exists already
                
                let myFileManager = NSFileManager()
                let myPrefFile = NSHomeDirectory().stringByAppendingString("/Library/Preferences/com.apple.Kerberos.plist")
                
                if ( !myFileManager.fileExistsAtPath(myPrefFile)) {
                    // no existing pref file
                    
                    let data = NSMutableDictionary()
                    let realms = NSMutableDictionary()
                    let realm = NSMutableDictionary()
                    
                    realm.setValue(defaults.stringForKey("CurrentLDAPServer")!, forKey: "kdc")
                    realm.setValue(defaults.stringForKey("CurrentLDAPServer")!, forKey: "kpasswd")
                    
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
    
}
