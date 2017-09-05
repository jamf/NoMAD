//
//  KeychainMinder.swift
//  NoMAD
//
//  Created by Joel Rennich on 4/25/17.
//  Copyright © 2017 Orchard & Grove Inc. All rights reserved.
//

import Foundation

let keychainMinder = KeychainMinder()

class KeychainMinder : NSWindowController, NSWindowDelegate {

    // class to manage the Keychain Minder window

    // UI bits

    @IBOutlet weak var messageText: NSTextField!
    @IBOutlet weak var oldPassword: NSSecureTextField!
    @IBOutlet weak var newPassword: NSSecureTextField!

    @IBOutlet weak var changeButton: NSButton!
    @IBOutlet weak var ignoreButton: NSButton!
    @IBOutlet weak var newKeychainButton: NSButton!

    @IBOutlet weak var activitySpinner: NSProgressIndicator!

    // variables

    // overrides

    override var windowNibName: String? {
        return "KeychainMinder"
    }

    override func windowDidLoad() {
        clearWindow()
        
        // pull in any customizations
        
        // window name
        
        self.window?.title = defaults.string(forKey: Preferences.keychainMinderWindowTitle) ?? "Keychain Locked"
        
        // window text
        
        if let customText = defaults.string(forKey: Preferences.keychainMinderWindowMessage) {
            messageText.stringValue = customText
        }
        
        // show create new button
        
    }


    func windowWillClose(_ notification: Notification) {
        stopOperations()
        clearWindow()
        
        // update NoMAD
        
        NotificationCenter.default.post(updateNotification)

    }

    // functions

    func clearWindow() {
        // clear out the fields

        oldPassword.stringValue = ""
        newPassword.stringValue = ""
        activitySpinner.stopAnimation(nil)
        activitySpinner.isHidden = true
    }

    func startOperations() {
        activitySpinner.startAnimation(nil)
        activitySpinner.isHidden = false
        changeButton.isEnabled = false
        newPassword.isEnabled = false
        oldPassword.isEnabled = false
    }

    func stopOperations() {
        activitySpinner.stopAnimation(nil)
        activitySpinner.isHidden = true
        newPassword.isEnabled = true
        oldPassword.isEnabled = true
    }

    func changePassword() -> String {

        let new = newPassword.stringValue
        let old = oldPassword.stringValue

        do {
            // get a NoMADUser object to do all the work

            let noMADUser = try NoMADUser(kerberosPrincipal: "someone@SOMEWHERE.COM")

            // check the new password

            if noMADUser.checkCurrentConsoleUserPassword(new) != "Valid" {
                // return "New password does not match your current local user password."
            }

            // check the old password

            if try noMADUser.checkKeychainPassword(old, true) {
                try noMADUser.changeKeychainPassword(old, newPassword1: new, newPassword2: new)
            }

        } catch {

            return error.localizedDescription
            
        }
        return ""
    }

    func resetLocalKeychain() -> String {

        let new = newPassword.stringValue

        do {
            // get a NoMADUser object to do all the work

            let noMADUser = try NoMADUser(kerberosPrincipal: "someone@SOMEWHERE.COM")

            // check the new password

            if noMADUser.checkCurrentConsoleUserPassword(new) != "Valid" {
                //   return "New password does not match your current local user password."
            }

            // check the old password

            try noMADUser.resetLocalKeychain(new)

        } catch {

            return error.localizedDescription
            
        }
        
        return ""
    }

    func showAlert(message: String) {

        let myAlert = NSAlert()
        myAlert.messageText = message
        myAlert.beginSheetModal(for: NSApp.mainWindow!, completionHandler: nil)
    }

    // button actions

    @IBAction func changeButtonClick(_ sender: Any) {

        startOperations()
        let message = changePassword()
        stopOperations()

        if message != "" {
            showAlert(message: message)
        } else {
            self.window?.close()
        }
    }

    @IBAction func ignoreButtonClick(_ sender: Any) {

        // go away

        self.window?.close()

    }

    @IBAction func newButtonClick(_ sender: Any) {

        startOperations()
        let message = resetLocalKeychain()
        stopOperations()
        if message != "" {
            showAlert(message: message)
        } else {
            self.window?.close()
        }
    }
}
