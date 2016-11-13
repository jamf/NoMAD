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

    @IBOutlet weak var ADDomainTextField: NSTextField!
    @IBOutlet weak var KerberosRealmField: NSTextField!
    //@IBOutlet weak var InternalSiteField: NSTextField!
    //@IBOutlet weak var InternalSiteIPField: NSTextField!
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

        // set the fields and disable them if they're managed

        ADDomainTextField.stringValue = defaults.string(forKey: ADDomain) ?? ""

        if defaults.objectIsForced(forKey: ADDomain) {
            ADDomainTextField.isEnabled = false
        } else {
            ADDomainTextField.isEnabled = true
        }

        KerberosRealmField.stringValue = defaults.string(forKey: "KerberosRealm") ?? ""

        if defaults.objectIsForced(forKey: "KerberosRealm") {
            KerberosRealmField.isEnabled = false
        } else {
            KerberosRealmField.isEnabled = true
        }
        /*
         InternalSiteField.stringValue = defaults.stringForKey("InternalSite") ?? ""

         if defaults.objectIsForcedForKey("InternalSite") {
         InternalSiteField.enabled = false
         } else {
         InternalSiteField.enabled = true
         }

         InternalSiteIPField.stringValue = defaults.stringForKey("InternalSiteIP") ?? ""

         if defaults.objectIsForcedForKey("InternalSiteIP") {
         InternalSiteIPField.enabled = false
         } else {
         InternalSiteIPField.enabled = true
         }
         */
        x509CAField.stringValue = defaults.string(forKey: "x509CA") ?? ""

        if defaults.objectIsForced(forKey: "x509CA") {
            x509CAField.isEnabled = false
        } else {
            x509CAField.isEnabled = true
        }

        TemplateField.stringValue = defaults.string(forKey: "Template") ?? ""

        if defaults.objectIsForced(forKey: "Template") {
            TemplateField.isEnabled = false
        } else {
            TemplateField.isEnabled = true
        }

        // now the secret stuff

        ButtonNameField.stringValue = defaults.string(forKey: "userCommandName1") ?? ""

        if defaults.objectIsForced(forKey: "userCommandName1") {
            ButtonNameField.isEnabled = false
        } else {
            ButtonNameField.isEnabled = true
        }

        HotKeyField.stringValue = defaults.string(forKey: "userCommandHotKey1") ?? ""

        if defaults.objectIsForced(forKey: "userCommandHotKey1") {
            HotKeyField.isEnabled = false
        } else {
            HotKeyField.isEnabled = true
        }

        CommandField.stringValue = defaults.string(forKey: "userCommandTask1") ?? ""

        if defaults.objectIsForced(forKey: "userCommandTask1") {
            CommandField.isEnabled = false
        } else {
            CommandField.isEnabled = true
        }

        // now the buttons

        UseKeychain.state = defaults.integer(forKey: "UseKeychain") ?? 0

        if defaults.objectIsForced(forKey: "UseKeychain") {
            UseKeychain.isEnabled = false
        } else {
            UseKeychain.isEnabled = true
        }

        RenewTickets.state = defaults.integer(forKey: "RenewTickets") ?? 1

        if defaults.objectIsForced(forKey: "RenewTickets") {
            RenewTickets.isEnabled = false
        } else {
            RenewTickets.isEnabled = true
        }

        ShowHome.state = defaults.integer(forKey: "ShowHome") ?? 0

        if defaults.objectIsForced(forKey: "ShowHome") {
            ShowHome.isEnabled = false
        } else {
            ShowHome.isEnabled = true
        }

        // and the seconds

        SecondsToRenew.stringValue = String(defaults.integer(forKey: "SecondsToRenew") )

        if defaults.objectIsForced(forKey: "SecondsToRenew") {
            SecondsToRenew.isEnabled = false
        } else {
            SecondsToRenew.isEnabled = true
        }

    }

    func windowShouldClose(_ sender: Any) -> Bool {

        // make sure we have an AD Domain

        if ADDomainTextField.stringValue == "" {
            let alertController = NSAlert()
            alertController.messageText = "The AD Domain needs to be filled out."
            alertController.addButton(withTitle: "OK")
            alertController.addButton(withTitle: "Quit NoMAD")
            alertController.beginSheetModal(for: self.window!, completionHandler: {( response ) in
                if ( response == 1001 ) {
                    NSApp.terminate(self)
                } else {
                }
            })
            return false
        } else {
            return true
        }
    }

    func windowWillClose(_ notification: Notification) {

        // turn the fields into app defaults

        defaults.set(ADDomainTextField.stringValue, forKey: ADDomain)
        if ( KerberosRealmField.stringValue == "" ) {
            defaults.set(ADDomainTextField.stringValue.uppercased(), forKey: "KerberosRealm")
        } else {
            defaults.set(KerberosRealmField.stringValue.uppercased(), forKey: "KerberosRealm")
        }
        //defaults.setObject(InternalSiteField.stringValue, forKey: "InternalSite")
        //defaults.setObject(InternalSiteIPField.stringValue, forKey: "InternalSiteIP")
        defaults.set(x509CAField.stringValue, forKey: "x509CA")
        defaults.set(TemplateField.stringValue, forKey: "Template")

        // secret stuff

        defaults.set(ButtonNameField.stringValue, forKey: "userCommandName1")
        defaults.set(HotKeyField.stringValue, forKey: "userCommandHotKey1")
        defaults.set(CommandField.stringValue, forKey: "userCommandTask1")

        // buttons

        defaults.set(UseKeychain.state, forKey: "UseKeychain")
        defaults.set(RenewTickets.state, forKey: "RenewTickets")
        defaults.set(ShowHome.state, forKey: "ShowHome")

        // and the seconds

        defaults.set(Int(SecondsToRenew.stringValue), forKey: "SecondsToRenew")
        notificationCenter.post(notificationKey)

    }

}
