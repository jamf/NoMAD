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
        
        var myError = ""
        
        if ( newPassword.stringValue == newPasswordAgain.stringValue) {
            
            let ChangePassword: KerbUtil = KerbUtil()
            print(defaults.stringForKey("userPrincipal")!)
            myError = ChangePassword.changeKerbPassword(oldPassword.stringValue, newPassword.stringValue, defaults.stringForKey("userPrincipal")!.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()))
            
            if (defaults.integerForKey("LocalPasswordSync") == 1 ) && myError == "" {
                do { try testLocalPassword(oldPassword.stringValue) }
                    catch {
                        NSLog("Local password check Swift = no")
                        myError = "Your current local password does not match your AD password."
                    }
            }
            
            if (defaults.integerForKey("LocalPasswordSync") == 1 ) && myError == "" {
                // synch keychain
                if (ChangePassword.changeKeychainPassword(oldPassword.stringValue, newPassword.stringValue) == 0) {
                    NSLog("Error changing local keychain")
                    myError = "Could not change your local keychain password."
                }
            }
            
            if (defaults.stringForKey("LocalPasswordSynch") != "" ) && myError == "" {
                // synch local passwords
                do { try changeLocalPassword( oldPassword.stringValue, newPassword: newPassword.stringValue) }
                catch {
                    NSLog("Local password change failed")
                    myError = "Local password change failed"
                }
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
            NSLog(myError)
        } else {
            
            let alertController = NSAlert()
            alertController.messageText = "New passwords don't match!"
            alertController.beginSheetModalForWindow(self.window!, completionHandler: nil)
            EXIT_FAILURE
            
        }
        
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
