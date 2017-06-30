//
//  PreferencesWindow.swift
//  NoMAD
//
//  Created by Joel Rennich on 4/21/16.
//  Copyright © 2016 Trusource Labs. All rights reserved.
//

import Cocoa

protocol PreferencesWindowDelegate {
    func doTheNeedfull()
}

class PreferencesWindow: NSWindowController, NSWindowDelegate {

    var delegate: PreferencesWindowDelegate?

    // The UI controls are connected with simple SharedDefaults bindings.
    // This means that they stay syncronized with the Defaults system and we
    // don't need to get into messing with state checking when loading the window.

    @IBOutlet weak var ADDomainTextField: NSTextField!
    @IBOutlet weak var KerberosRealmField: NSTextField!
    @IBOutlet weak var x509CAField: NSTextField!
    @IBOutlet weak var TemplateField: NSTextField!
    @IBOutlet weak var ButtonNameField: NSTextField!
    @IBOutlet weak var HotKeyField: NSTextField!
    @IBOutlet weak var CommandField: NSTextField!
    @IBOutlet weak var SecondsToRenew: NSTextField!

    // Check boxes
    @IBOutlet weak var UseKeychain: NSButton!
    @IBOutlet weak var RenewTickets: NSButton!
    @IBOutlet weak var ShowHome: NSButton!

    override var windowNibName: String? {
        return "PreferencesWindow"
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        self.window?.center()
        self.disableManagedPrefs()
    }

    func windowShouldClose(_ sender: Any) -> Bool {

        // Make sure we have an AD Domain. Either require the user to enter one
        // or quit.
        if ADDomainTextField.stringValue == "" {
            let alertController = NSAlert()
            alertController.messageText = "The AD Domain needs to be filled out."
            alertController.addButton(withTitle: "OK")
            alertController.addButton(withTitle: "Quit NoMAD")
            alertController.beginSheetModal(for: self.window!) { response in
                if response == 1001 {
                    NSApp.terminate(self)
                }
            }
            return false
        }
        return true
    }

    func windowWillClose(_ notification: Notification) {
        // If no Kerberos realm has been entered, assume it's the same as the AD Domain.
        if KerberosRealmField.stringValue == "" {
            defaults.set(ADDomainTextField.stringValue.uppercased(), forKey: Preferences.kerberosRealm)
        }

        // double check that we have a Kerberos Realm

        if defaults.string(forKey: Preferences.kerberosRealm) == "" || defaults.string(forKey: Preferences.kerberosRealm) == nil {
            defaults.set(defaults.string(forKey: Preferences.aDDomain)?.uppercased(), forKey: Preferences.kerberosRealm)
        }

        // update the Chrome configuration

        if defaults.bool(forKey: Preferences.configureChrome) {
            configureChrome()
        }

        NotificationCenter.default.post(updateNotification)
    }

    /// Disable the UI for managed preferences.
    ///
    /// Because of naming disparities we are cycling through the controls in
    /// the `contentView` of the window and looking at their `identifier` keys.
    /// These keys are set to the same string as the preference value they
    /// control.
    func disableManagedPrefs() {
        guard let controls = self.window?.contentView?.subviews else {
            myLogger.logit(.debug, message: "Preference window somehow drew without any controls.")
            return
        }
        //MARK: TODO This smells to be overly clever. We should find a simpler way.
        for object in controls {
            let identifier = object.identifier
            if defaults.objectIsForced(forKey: identifier!) {
                switch object.className {
                case "NSTextField":
                    let textField = object as! NSTextField
                    textField.isEnabled = false
                case "NSButton":
                    let button = object as! NSButton
                    button.isEnabled = false
                default:
                    return
                }
            }
        }
    }

    func configureChrome() {

        // create new instance of defaults for com.google.Chrome

        let chromeDefaults = UserDefaults.init(suiteName: "com.google.Chrome")
        var chromeDomain = defaults.string(forKey: Preferences.configureChromeDomain) ?? defaults.string(forKey: Preferences.aDDomain)!

        // add the wildcard

        chromeDomain = "*" + chromeDomain

        var change = false

        // find the keys and add the domain

        let chromeAuthServer = chromeDefaults?.string(forKey: "AuthServerWhitelist")
        var chromeAuthServerArray = chromeAuthServer?.components(separatedBy: ",")

        if chromeAuthServerArray != nil {
            if !((chromeAuthServerArray?.contains(chromeDomain))!) {
                chromeAuthServerArray?.append(chromeDomain)
                change = true
            }
        } else {
            chromeAuthServerArray = [chromeDomain]
            change = true
        }

        let chromeAuthNegotiate = chromeDefaults?.string(forKey: "AuthNegotiateDelegateWhitelist")
        var chromeAuthNegotiateArray = chromeAuthNegotiate?.components(separatedBy: ",")

        if chromeAuthNegotiateArray != nil {
            if !((chromeAuthNegotiateArray?.contains(chromeDomain))!) {
                chromeAuthNegotiateArray?.append(chromeDomain)
                change = true
            }
        } else {
            chromeAuthNegotiateArray = [chromeDomain]
            change = true
        }

        // write it back

        if change {
            chromeDefaults?.set(chromeAuthServerArray?.joined(separator: ","), forKey: "AuthServerWhitelist")
            chromeDefaults?.set(chromeAuthNegotiateArray?.joined(separator: ","), forKey: "AuthNegotiateDelegateWhitelist")
        }
    }
}
