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
        self.window?.makeKeyAndOrderFront(nil)
        NSApp.activateIgnoringOtherApps(true)
        
        // set the fields and disable them if they're managed
        
        ADDomainTextField.stringValue = defaults.stringForKey("ADDomain") ?? ""
        
        if defaults.objectIsForcedForKey("ADDomain") {
            ADDomainTextField.enabled = false
        } else {
            ADDomainTextField.enabled = true
        }
        
        KerberosRealmField.stringValue = defaults.stringForKey("KerberosRealm") ?? ""
        
        if defaults.objectIsForcedForKey("KerberosRealm") {
            KerberosRealmField.enabled = false
        } else {
            KerberosRealmField.enabled = true
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
        x509CAField.stringValue = defaults.stringForKey("x509CA") ?? ""
        
        if defaults.objectIsForcedForKey("x509CA") {
            x509CAField.enabled = false
        } else {
            x509CAField.enabled = true
        }
        
        TemplateField.stringValue = defaults.stringForKey("Template") ?? ""
        
        if defaults.objectIsForcedForKey("Template") {
            TemplateField.enabled = false
        } else {
            TemplateField.enabled = true
        }
        
        // now the secret stuff
        
        ButtonNameField.stringValue = defaults.stringForKey("userCommandName1") ?? ""
        
        if defaults.objectIsForcedForKey("userCommandName1") {
            ButtonNameField.enabled = false
        } else {
            ButtonNameField.enabled = true
        }
        
        HotKeyField.stringValue = defaults.stringForKey("userCommandHotKey1") ?? ""
        
        if defaults.objectIsForcedForKey("userCommandHotKey1") {
            HotKeyField.enabled = false
        } else {
            HotKeyField.enabled = true
        }
        
        CommandField.stringValue = defaults.stringForKey("userCommandTask1") ?? ""
        
        if defaults.objectIsForcedForKey("userCommandTask1") {
            CommandField.enabled = false
        } else {
            CommandField.enabled = true
        }
        
        // now the buttons
        
        UseKeychain.state = defaults.integerForKey("UseKeychain") ?? 0
        
        if defaults.objectIsForcedForKey("UseKeychain") {
            UseKeychain.enabled = false
        } else {
            UseKeychain.enabled = true
        }
        
        RenewTickets.state = defaults.integerForKey("RenewTickets") ?? 1
        
        if defaults.objectIsForcedForKey("RenewTickets") {
            RenewTickets.enabled = false
        } else {
            RenewTickets.enabled = true
        }
        
        ShowHome.state = defaults.integerForKey("ShowHome") ?? 0
        
        if defaults.objectIsForcedForKey("ShowHome") {
            ShowHome.enabled = false
        } else {
            ShowHome.enabled = true
        }
        
        // and the seconds
        
        SecondsToRenew.stringValue = String(defaults.integerForKey("SecondsToRenew") )
        
        if defaults.objectIsForcedForKey("SecondsToRenew") {
            SecondsToRenew.enabled = false
        } else {
            SecondsToRenew.enabled = true
        }

    }
    
    func windowShouldClose(sender: AnyObject) -> Bool {
        
        // make sure we have an AD Domain
        
        if ADDomainTextField.stringValue == "" {
            let alertController = NSAlert()
            alertController.messageText = "The AD Domain needs to be filled out."
            alertController.beginSheetModalForWindow(self.window!, completionHandler: nil)
            return false
        } else {
            return true
        }
    }
    
    func windowWillClose(notification: NSNotification) {
        
        // turn the fields into app defaults
        
        defaults.setObject(ADDomainTextField.stringValue, forKey: "ADDomain")
        if ( KerberosRealmField.stringValue == "" ) {
            defaults.setObject(ADDomainTextField.stringValue.uppercaseString, forKey: "KerberosRealm")
        } else {
            defaults.setObject(KerberosRealmField.stringValue, forKey: "KerberosRealm")
        }
        //defaults.setObject(InternalSiteField.stringValue, forKey: "InternalSite")
        //defaults.setObject(InternalSiteIPField.stringValue, forKey: "InternalSiteIP")
        defaults.setObject(x509CAField.stringValue, forKey: "x509CA")
        defaults.setObject(TemplateField.stringValue, forKey: "Template")
        
        // secret stuff
        
        defaults.setObject(ButtonNameField.stringValue, forKey: "userCommandName1")
        defaults.setObject(HotKeyField.stringValue, forKey: "userCommandHotKey1")
        defaults.setObject(CommandField.stringValue, forKey: "userCommandTask1")
        
        // buttons
        
        defaults.setObject(UseKeychain.state, forKey: "UseKeychain")
        defaults.setObject(RenewTickets.state, forKey: "RenewTickets")
        defaults.setObject(ShowHome.state, forKey: "ShowHome")
        
        // and the seconds
        
        defaults.setObject(Int(SecondsToRenew.stringValue), forKey: "SecondsToRenew")
        notificationCenter.postNotification(notificationKey)
                
    }
    
}
