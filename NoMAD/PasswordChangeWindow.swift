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

            var totalMatches = 0

            // TODO: set up all of these for translation

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

            if totalMatches >= Int(minMatches)! && Int(minMatches) != 0 && pass.characters.count >= Int(minLength)! {
                result = ""
            }

        return result
    }

    override func controlTextDidChange(_ obj: Notification) {
        let error = checkPassword(pass: newPassword.stringValue)

        if error == "" {
            policyAlert.image = NSImage.init(imageLiteralResourceName: NSImageNameStatusAvailable)
            policyAlert.toolTip = "All requirements met."
        } else {
            policyAlert.image = NSImage.init(imageLiteralResourceName: NSImageNameStatusUnavailable)
            policyAlert.toolTip = error
            passwordChangeButton.isEnabled = false

        }

        if newPasswordAgain.stringValue == newPassword.stringValue && error == "" {
            secondaryAlert.image = NSImage.init(imageLiteralResourceName: NSImageNameStatusAvailable)
            secondaryAlert.toolTip = "All requirements met."
            passwordChangeButton.isEnabled = true

        } else {
            secondaryAlert.image = NSImage.init(imageLiteralResourceName: NSImageNameStatusUnavailable)
            secondaryAlert.toolTip = "Passwords don't match."
            passwordChangeButton.isEnabled = false
        }
    }

}
