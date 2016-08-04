//
//  NoMADMenuController.swift
//  NoMAD
//
//  Created by Admin on 7/8/16.
//  Copyright © 2016 Trusource Labs. All rights reserved.
//

import Foundation
import Cocoa
import SecurityFoundation
import SystemConfiguration

// Error codes

enum NoADError: ErrorType {
    case NotConnected
    case NotLoggedIn
    case NoPasswordExpirationTime
    case LDAPServerLookup
    case LDAPNamingContext
    case LDAPServerPasswordExpiration
    case UserPasswordSetDate
    case UserHome
}


// set up a default defaults

let defaults = NSUserDefaults.standardUserDefaults()
let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(NSVariableStatusItemLength)
let userNotificationCenter = NSUserNotificationCenter.defaultUserNotificationCenter()
var selfServiceExists = true

class NoMADMenuController: NSObject, LoginWindowDelegate, PasswordChangeDelegate, PreferencesWindowDelegate {
    
    // menu item connections
    
    @IBOutlet weak var NoMADMenu: NSMenu!
    @IBOutlet weak var NoMADMenuUserName: NSMenuItem!
    @IBOutlet weak var NoMADMenuPasswordExpires: NSMenuItem!
    @IBOutlet weak var NoMADMenuLogIn: NSMenuItem!
    @IBOutlet weak var NoMADMenuChangePassword: NSMenuItem!
    @IBOutlet weak var NoMADMenuLogOut: NSMenuItem!
    @IBOutlet weak var NoMADMenuLockScreen: NSMenuItem!
    @IBOutlet weak var NoMADMenuGetCertificate: NSMenuItem!
    @IBOutlet weak var NoMADMenuGetSoftware: NSMenuItem!
    @IBOutlet weak var NoMADMenuGetHelp: NSMenuItem!
    @IBOutlet weak var NoMADMenuHiddenItem1: NSMenuItem!
    @IBOutlet weak var NoMADMenuPreferences: NSMenuItem!
    @IBOutlet weak var NoMADMenuQuit: NSMenuItem!
    @IBOutlet weak var NoMADMenuSpewLogs: NSMenuItem!
    @IBOutlet weak var NoMADMenuTicketLife: NSMenuItem!
    @IBOutlet weak var NoMADMenuLogInAlternate: NSMenuItem!
    
    let NoMADMenuHome = NSMenuItem()
    
    // menu bar icons
    
    let iconOnOn = NSImage(named: "NoMAD-statusicon-on-on")
    let iconOnOff = NSImage(named: "NoMAD-statusicon-on-off")
    let iconOffOff = NSImage(named: "NoMAD-statusicon-off-off")
    
    // for delegates
    
    var loginWindow: LoginWindow!
    var preferencesWindow: PreferencesWindow!
    var passwordChangeWindow: PasswordChangeWindow!
    
    // globals
    
    let userInfoAPI = UserInfoAPI()
    
    var lastStatusCheck = NSDate().dateByAddingTimeInterval(-5000)
    var updateScheduled = false
    let dateFormatter = NSDateFormatter()
    
    // on startup we check for preferences
    
    override func awakeFromNib() {
        
        preferencesWindow = PreferencesWindow()
        loginWindow = LoginWindow()
        passwordChangeWindow = PasswordChangeWindow()
        
        loginWindow.delegate = self
        passwordChangeWindow.delegate = self
        preferencesWindow.delegate = self
        
        dateFormatter.dateStyle = .MediumStyle
        dateFormatter.timeStyle = .ShortStyle
        
        
        // find out if Casper Self Service exists - hide the menu if it's not there
        
        let selfServiceFileManager = NSFileManager.defaultManager()
        selfServiceExists = selfServiceFileManager.fileExistsAtPath("/Applications/Self Service.app")
        
        if !selfServiceExists {
            if NoMADMenu.itemArray.contains(NoMADMenuGetSoftware) {
                NoMADMenuGetSoftware.enabled = false
                NoMADMenu.removeItem(NoMADMenuGetSoftware)
            }
        }
        
        // listen for updates
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(doTheNeedfull), name: "updateNow", object: nil)
        
        // see if we should auto-configure
        
        setDefaults()
        
        // if no preferences are set, we show the preferences pane
        
        if ( defaults.stringForKey("ADDomain") ?? "" == "" ) {
             preferencesWindow.showWindow(nil)
        } else {
            
            if  ( defaults.stringForKey("LastPasswordWaring") ?? "" == "" ) {
                defaults.setObject(172800, forKey: "LastPasswordWarning")
            }
            
            if ( defaults.stringForKey("Verbose") ?? "" == "" ) {
                defaults.setObject(0, forKey: "Verbose")
            }
            doTheNeedfull()
        }
        
        if defaults.integerForKey("Verbose") >= 1 {
            NSLog("Starting up NoMAD")
        }
        
    }
    
    // actions for the menu items
    
    // show the login window when the menu item is clicked
    
    @IBAction func NoMADMenuClickLogIn(sender: NSMenuItem) {
                loginWindow.showWindow(nil)
    }
    
    // show the password change window when the menu item is clicked
    
    @IBAction func NoMADMenuClickChangePassword(sender: NSMenuItem) {
             passwordChangeWindow.showWindow(nil)
        //       updateUserInfo()
    }
    
    // kill the Kerb ticket when clicked

    @IBAction func NoMADMenuClickLogOut(sender: NSMenuItem) {
        cliTask("/usr/bin/kdestroy")
        updateUserInfo()
    }
    
    // lock the screen when clicked
    
    @IBAction func NoMADMenuClickLockScreen(sender: NSMenuItem) {
        //  cliTask("/System/Library/CoreServices/Menu\\ Extras/User.menu/Contents/Resources/CGSession -suspend")

            let registry: io_registry_entry_t = IORegistryEntryFromPath(kIOMasterPortDefault, "IOService:/IOResources/IODisplayWrangler")
            let _ = IORegistryEntrySetCFProperty(registry, "IORequestIdle", true)
            IOObjectRelease(registry)

    }
    
    // gets a cert from the Windows CA
    
    @IBAction func NoMADMenuClickGetCertificate(sender: NSMenuItem) {
        
        // TODO: check to see if the SSL Certs are trusted, otherwise we'll fail
        // TODO: check if a valid cert is already present and then warn
        
        // need pre-flight to ensure valid URL and template
        
        let certCATest = defaults.stringForKey("x509CA") ?? ""
        let certTemplateTest = defaults.stringForKey("Template") ?? ""
        
        if ( certCATest != "" && certTemplateTest != "" ) {
        
        let certCARequest = WindowsCATools(serverURL: certCATest, template: certTemplateTest)
        certCARequest.certEnrollment()
        } else {
            let certAlertController = NSAlert()
            certAlertController.messageText = "Please ensure your Certificate Authority settings are correct."
            certAlertController.runModal()
        }
    }
    
    
    // opens up Casper Self Service - this should only be shown if Self Service exists on the machine
    
    @IBAction func NoMADMenuClickGetSoftware(sender: NSMenuItem) {
                cliTask("/usr/bin/open /Applications/Self\\ Service.app")
    }
    
    // this downloads the Bomgar client and launches it, passing in various bits of info
    
    @IBAction func NoMADMenuClickGetHelp(sender: NSMenuItem) {
    let myGetHelp = GetHelp()
        myGetHelp.getHelp()
    }
     
    // if specified by the preferences, this shows a CLI one-liner
    
    @IBAction func NoMADMenuClickHiddenItem1(sender: NSMenuItem) {
        let myResult = cliTask(defaults.stringForKey("userCommandTask1")!)
        NSLog(myResult)
    }

    // shows the preferences window
    
    @IBAction func NoMADMenuClickPreferences(sender: NSMenuItem) {
        preferencesWindow = PreferencesWindow()
        preferencesWindow.showWindow(nil)
    }
    
    // quit when asked
    
    @IBAction func NoMADMenuClickQuit(sender: NSMenuItem) {
                NSApplication.sharedApplication().terminate(self)
    }

    // connect to the Home share if it's available
    
    @IBAction func homeClicked(send: AnyObject) {
        cliTask("open smb:" + defaults.stringForKey("userHome")!)
    }
    
    // send copious logs to the console
    
    @IBAction func NoMADMenuClickSpewLogs(sender: AnyObject) {
        NSLog("---- Spew Logs ----")

        NSLog("User information state:")
        NSLog("Connection test URL: " + userInfoAPI.connectionData["connectionTestURL"]!)
        NSLog("Connection test result: " + userInfoAPI.connectionData["connectionTestResult"]!)
        NSLog("Realm: " + userInfoAPI.connectionData["realm"]!)
        NSLog("Domain: " + userInfoAPI.connectionData["domain"]!)
        NSLog("LDAP Server: " + userInfoAPI.connectionData["ldapServer"]!)
        NSLog("LDAP Server Naming Context: " + userInfoAPI.connectionData["ldapServerNamingContext"]!)
        NSLog("Password expiration default: " + String(userInfoAPI.serverPasswordExpirationDefault))
        NSLog("Password aging: " + String(userInfoAPI.connectionFlags["passwordAging"]!))
        NSLog("Connected: " + String(userInfoAPI.connectionFlags["isConnected"]!))
        NSLog("Status: " + String(userInfoAPI.connectionData["status"]!))
        NSLog("User short name: " + getConsoleUser())
        NSLog("User long name: " + NSUserName())
        NSLog("User principal: " + userInfoAPI.connectionData["userPrincipal"]!)
        NSLog("TGT expires: " + String(userInfoAPI.connectionDates["userTicketExpireTime"]!))
        NSLog("User password set date: " + String(userInfoAPI.connectionDates["userPasswordSetDate"]!))
        NSLog("User password expire date: " + String(userInfoAPI.connectionDates["userPasswordExpireDate"]!))
        NSLog("User home share: " + userInfoAPI.connectionData["userHome"]!)
        
        NSLog("---- User Record ----")
        logEntireUserRecord()
        NSLog("---- Kerberos Tickets ----")
        NSLog(userInfoAPI.myTickets.returnAllTickets())

    }
    
    @IBAction func NoMADMenuClickLogInAlternate(sender: AnyObject) {
                        loginWindow.showWindow(nil)
    }
    
    // this will update the menu when it's clicked
    
    override func validateMenuItem(menuItem: NSMenuItem) -> Bool {
        
        if menuItem.title == "Lock Screen" {
            updateUserInfo()
        }
        
        // disable the menus that don't work if you're not logged in
        
        if self.userInfoAPI.connectionFlags["isConnected"] == false {
            
            self.NoMADMenuLogIn.enabled = false
            self.NoMADMenuLogIn.title = "Log In"
            self.NoMADMenuLogOut.enabled = false
            self.NoMADMenuChangePassword.enabled = false
            self.NoMADMenuGetCertificate.enabled = false
            
            // twiddles what needs to be twiddled for connected but not logged in
            
        } else if self.userInfoAPI.connectionFlags["isLoggedIn"] == false {
            
            self.NoMADMenuLogIn.enabled = true
            self.NoMADMenuLogIn.title = "Log In"
            self.NoMADMenuLogIn.action = #selector(self.NoMADMenuClickLogIn)
            self.NoMADMenuLogOut.enabled = false
            self.NoMADMenuChangePassword.enabled = false
            self.NoMADMenuGetCertificate.enabled = false
            
            }
        else {
            self.NoMADMenuLogIn.enabled = true
            self.NoMADMenuLogIn.title = "Renew Tickets"
            self.NoMADMenuLogIn.action = #selector(self.renewTickets)
            self.NoMADMenuLogOut.enabled = true
            self.NoMADMenuChangePassword.enabled = true
            self.NoMADMenuGetCertificate.enabled = true
        }
        
        return true
    }
    
    // display a user notifcation
    
    func showNotification(title: String, text: String, date: NSDate) -> Void {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = text
        //notification.deliveryDate = date
        notification.hasActionButton = true
        notification.actionButtonTitle = "Change Password"
        notification.soundName = NSUserNotificationDefaultSoundName
        userNotificationCenter.deliverNotification(notification)
    }
    
    // pulls user's entire LDAP record when asked
    
    func logEntireUserRecord() {
        let myResult = userInfoAPI.myLDAPServers.returnFullRecord("sAMAccountName=" + defaults.stringForKey("LastUser")!)
        NSLog(myResult)
    }

    // everything to do on a network change
    
    func doTheNeedfull() {
        if ( userInfoAPI.myLDAPServers.getDomain() == "not set" ) {
            userInfoAPI.myLDAPServers.setDomain(defaults.stringForKey("ADDomain")!)
            userInfoAPI.myTickets.getDetails()
        }

        userInfoAPI.myLDAPServers.check()
        updateUserInfo()
    }
    
    // simple function to renew tickets
    
    func renewTickets(){
        cliTask("/usr/bin/kinit -R")
        userInfoAPI.myTickets.getDetails()
        if defaults.integerForKey("Verbose") >= 1 {
            NSLog("Renewing tickets.")
        }
    }
    
    // update the user info and build the actual menu
    
    func updateUserInfo() {
        
        NSLog("Updating User Info")
        
        // make sure the domain we're using is the domain we should be using
        
        if ( userInfoAPI.myLDAPServers.getDomain() != defaults.stringForKey("ADDomain")!) {
             userInfoAPI.myLDAPServers.setDomain(defaults.stringForKey("ADDomain")!)
        }
        
        // get the information on the current setup
        
        let qualityBackground = QOS_CLASS_BACKGROUND
        let backgroundQueue = dispatch_get_global_queue(qualityBackground, 0)
        
        if abs(lastStatusCheck.timeIntervalSinceNow) > 3 {
        
        // through the magic of code blocks we'll update in the background
        
        dispatch_async(backgroundQueue, {
            let userinfo = self.userInfoAPI.checkAll()
            
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                // build the menu
                
                statusItem.menu = self.NoMADMenu
                
                // set the menu icon
                if userinfo!.status == "Connected" {
                    statusItem.image = self.iconOnOff
                   // we do this twice b/c doing it only once seems to make it less than full width
                    statusItem.title = userinfo!.status
                    statusItem.title = userinfo!.status
                    
                    // if we're not logged in we disable some options
                    
                    statusItem.toolTip = self.dateFormatter.stringFromDate(userinfo!.userPasswordExpireDate)
                    self.NoMADMenuTicketLife.title = "Not logged in."
                
                } else if userinfo!.status == "Logged In" {
                    statusItem.image = self.iconOnOn
                    
                    // if we're logged in we enable some options
                    
                    self.NoMADMenuLogOut.enabled = true
                    self.NoMADMenuChangePassword.enabled = true
                    
                    if userinfo!.passwordAging {
                        
                        statusItem.toolTip = self.dateFormatter.stringFromDate(userinfo!.userPasswordExpireDate)
                        self.NoMADMenuTicketLife.title = self.dateFormatter.stringFromDate(self.userInfoAPI.myTickets.expire) + " " + self.userInfoAPI.myLDAPServers.currentServer
                        
                        let daysToGo = Int(abs(userinfo!.userPasswordExpireDate.timeIntervalSinceNow)/86400)
                        // we do this twice b/c doing it only once seems to make it less than full width
                        if Int(daysToGo) > 4 {
                        statusItem.title = (String(daysToGo) + "d" )
                        statusItem.title = (String(daysToGo) + "d" )
                        } else {
                        
                        let myMutableString = NSMutableAttributedString(string: String(daysToGo) + "d")
                        myMutableString.addAttribute(NSForegroundColorAttributeName, value: NSColor.redColor(), range: NSRange(location: 0, length: 2))
                        statusItem.attributedTitle = myMutableString
                        statusItem.attributedTitle = myMutableString
                        }
                    } else {
                       
                        // we do this twice b/c doing it only once seems to make it less than full width
                        statusItem.title = ""
                        statusItem.title = ""
                         self.NoMADMenuTicketLife.title = self.dateFormatter.stringFromDate(self.userInfoAPI.myTickets.expire) + " " + self.userInfoAPI.myLDAPServers.currentServer
                    }
                } else {
                    statusItem.image = self.iconOffOff
                    
                    // we do this twice b/c doing it only once seems to make it less than full width
                    statusItem.title = userinfo!.status
                    statusItem.title = userinfo!.status
                }
                
                if ( userinfo!.userPrincipalShort != "No User" ) {
                self.NoMADMenuUserName.title = userinfo!.userPrincipalShort
                } else {
                    self.NoMADMenuUserName.title = defaults.stringForKey("LastUser") ?? "No User"
                }
                
                if ( !defaults.boolForKey("UserAging") ) && ( defaults.stringForKey("LastUser") != "" ) {
                    self.NoMADMenuPasswordExpires.title = "Password does not expire."
                } else if ( defaults.stringForKey("LastUser")) != "" {
                    let myDaysToGo = String(abs((defaults.objectForKey("LastPasswordExpireDate")!.timeIntervalSinceNow)!)/86400)
                    self.NoMADMenuPasswordExpires.title = "Password expires in: " + myDaysToGo.componentsSeparatedByString(".")[0] + " days"
                } else {
                    self.NoMADMenuPasswordExpires.title = ""
                }
                
                let futureDate = NSDate()
                futureDate.dateByAddingTimeInterval(300)
                
                // add shortname into the defaults
                
                defaults.setObject(userinfo!.userPrincipalShort, forKey: "UserShortName")
                
                // if a user command is specified, show it, otherwise remove the menu item
                
                if ( defaults.stringForKey("userCommandName1") != "" ) {
              
                    guard (self.NoMADMenuHiddenItem1 != nil) else {
                        //let NoMADMenuHiddenItem1 = NSMenuItem()
                        self.NoMADMenu.addItem(self.NoMADMenuHiddenItem1)
                        return
                    }
                    self.NoMADMenuHiddenItem1.enabled = true
                    self.NoMADMenuHiddenItem1.hidden = false
                    self.NoMADMenuHiddenItem1.title = defaults.stringForKey("userCommandName1")!
                    self.NoMADMenuHiddenItem1.keyEquivalent = defaults.stringForKey("userCommandHotKey1")!
                } else  {
                    guard (self.NoMADMenuHiddenItem1 == nil) else {
                         self.NoMADMenu.removeItem(self.NoMADMenuHiddenItem1)
                        return
                    }
                }
                
                // add home directory menu item
                
                if userinfo!.isConnected && defaults.integerForKey("ShowHome") == 1 {
                    
                    if ( userinfo!.userHome != "" && self.NoMADMenu.itemArray.contains(self.NoMADMenuHome) == false ) {
                        self.NoMADMenuHome.title = "Home Sharepoint"
                        self.NoMADMenuHome.action = #selector(self.homeClicked)
                        self.NoMADMenuHome.target = self.NoMADMenuLogOut.target
                        self.NoMADMenuHome.enabled = true
                        // should key this off of the position of the Preferences menu
                        let prefIndex = self.NoMADMenu.indexOfItem(self.NoMADMenuPreferences)
                        self.NoMADMenu.insertItem(self.NoMADMenuHome, atIndex: (prefIndex - 1 ))
                    } else if userinfo!.userHome != "" && self.NoMADMenu.itemArray.contains(self.NoMADMenuHome) {
                        self.NoMADMenuHome.title = "Home Sharepoint"
                        self.NoMADMenuHome.action = #selector(self.homeClicked)
                        self.NoMADMenuHome.target = self.NoMADMenuLogOut.target
                        self.NoMADMenuHome.enabled = true
                    } else if self.NoMADMenu.itemArray.contains(self.NoMADMenuHome) {
                        self.NoMADMenu.removeItem(self.NoMADMenuHome)
                        
                    }
                }
            })

            // check if we need to renew the ticket
            
            if defaults.integerForKey("RenewTickets") == 1 && userinfo!.status == "Logged In" && ( abs(userinfo!.userTicketExpireTime.timeIntervalSinceNow) >= Double(defaults.integerForKey("SecondsToRenew"))) {
                self.userInfoAPI.renewTickets()
            }
            
            // check if we need to notify the user
            
            
            // reset the counter if the password change is over the default
            
            if ( abs(userinfo!.userPasswordExpireDate.timeIntervalSinceNow) < Double(defaults.integerForKey("PasswordExpireAlertTime") ?? 1296000) ) {
                
                if ( abs(userinfo!.userPasswordExpireDate.timeIntervalSinceNow) < Double(defaults.integerForKey("LastPasswordWarning")) ) {
                    if ( abs(userinfo!.userPasswordExpireDate.timeIntervalSinceNow) > Double(345600) ) {
                        // expire is between default and four days so notify once a day
                        self.showNotification("Password about to expire!", text: "Your network password is about to expire on " + self.dateFormatter.stringFromDate(userinfo!.userPasswordExpireDate), date: NSDate())
                        defaults.setObject((abs(userinfo!.userPasswordExpireDate.timeIntervalSinceNow) - 86400 ), forKey: "LastPasswordWarning")
                    } else if ( abs(userinfo!.userPasswordExpireDate.timeIntervalSinceNow) > Double(86400) ) {
                        // expire is between 4 days and 1 day so notifiy every 12 hours
                        self.showNotification("Password about to expire!", text: "Your network password is about to expire on " + self.dateFormatter.stringFromDate(userinfo!.userPasswordExpireDate), date: NSDate())
                        defaults.setObject( (abs(userinfo!.userPasswordExpireDate.timeIntervalSinceNow) - 23200 ), forKey: "LastPasswordWarning")
                    } else {
                        // expire is less than 1 day so notifiy every hour
                        self.showNotification("Password about to expire!", text: "Your network password is about to expire on " + self.dateFormatter.stringFromDate(userinfo!.userPasswordExpireDate), date: NSDate())
                        defaults.setObject((abs(userinfo!.userPasswordExpireDate.timeIntervalSinceNow) - 3600 ), forKey: "LastPasswordWarning")
                    }
                }
            } else {
                defaults.setObject(Double(defaults.integerForKey("PasswordExpireAlertTime") ?? 1296000), forKey: "LastPasswordWarning")
            }
            
        })
            // mark the time and clear the update scheduled flag
            
            lastStatusCheck = NSDate()
            updateScheduled = false
            
        } else {
            NSLog("Time between system checks is too short, delaying")
            if ( !updateScheduled ) {
                NSTimer.scheduledTimerWithTimeInterval(3, target: self, selector: #selector(updateUserInfo), userInfo: nil, repeats: false)
                updateScheduled = true
            }
        }
    }

}