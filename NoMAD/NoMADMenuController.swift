//
//  NoMADMenuController.swift
//  NoMAD
//
//  Created by Joel Rennich on 7/8/16.
//  Copyright © 2016 Trusource Labs. All rights reserved.
//

import Cocoa
import SecurityFoundation
import SystemConfiguration

// Error codes
enum NoADError: Error {
    case notConnected
    case notLoggedIn
    case noPasswordExpirationTime
    case ldapServerLookup
    case ldapNamingContext
    case ldapServerPasswordExpiration
    case ldapConnectionError
    case userPasswordSetDate
    case userHome
    case noStoredPassword
    case storedPasswordWrong
}

// bitwise convenience
prefix operator ~~

prefix func ~~(value: Int) -> Bool {
    return (value > 0) ? true : false
}

class NoMADMenuController: NSObject, LoginWindowDelegate, PasswordChangeDelegate, PreferencesWindowDelegate, NSMenuDelegate {

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
    @IBOutlet weak var NoMADMenuGetCertificateDate: NSMenuItem!
    @IBOutlet weak var NoMADMenuTicketLife: NSMenuItem!
    @IBOutlet weak var NoMADMenuLogInAlternate: NSMenuItem!

    let NoMADMenuHome = NSMenuItem()

    // menu bar icons
    let iconOnOn = NSImage(named: "NoMAD-statusicon-on-on")
    let iconOnOff = NSImage(named: "NoMAD-statusicon-on-off")
    let iconOffOff = NSImage(named: "NoMAD-statusicon-off-off")

    // for delegates
    let preferencesWindow = PreferencesWindow()
    let loginWindow = LoginWindow()
    let passwordChangeWindow = PasswordChangeWindow()

    var originalGetCertificateMenu : NSMenuItem!
    var originalGetCertificateMenuDate : NSMenuItem!

    let userInformation = UserInformation()

    var lastStatusCheck = Date().addingTimeInterval(-5000)
    var updateScheduled = false

    //let myShareMounter = ShareMounter()

    var menuAnimationTimer = Timer()

    let myWorkQueue = DispatchQueue(label: "com.trusourcelabs.NoMAD.background_work_queue", attributes: [])

    var selfService: SelfServiceType?

    let statusItem = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength)

    /// Fired when the menu loads the first time
    override func awakeFromNib() {

        myLogger.logit(.base, message:"---Starting NoMAD---")

        let defaultPreferences = NSDictionary(contentsOf: Bundle.main.url(forResource: "DefaultPreferences", withExtension: "plist")!)
        defaults.register(defaults: defaultPreferences as! [String : Any])

        // Register for update notifications.
        NotificationCenter.default.addObserver(self, selector: #selector(doTheNeedfull), name: NSNotification.Name(rawValue: "updateNow"), object: nil)

        startMenuAnimationTimer()

        loginWindow.delegate = self
        passwordChangeWindow.delegate = self
        preferencesWindow.delegate = self

        // Allows us to force windows to show when menu clicked.
        self.NoMADMenu.delegate = self

        // if no preferences are set, we show the preferences pane
        if (defaults.string(forKey: Preferences.aDDomain) == "" ) {
            preferencesWindow.window!.forceToFrontAndFocus(nil)
        } else {
            doTheNeedfull()
        }

        // find out if a Self Service Solution exists - hide the menu item if it's not there
        myLogger.logit(.notice, message:"Looking for Self Service applications")
        if let discoveredService = SelfServiceManager().discoverSelfService() {
            selfService = discoveredService
        } else {
                NoMADMenuGetSoftware.isHidden = true
                myLogger.logit(.info, message:"Not using Self Service.")
        }

        // see if we should auto-configure
        setDefaults()

        // Autologin if you should
        userInformation.myLDAPServers.tickets.getDetails()
        autoLogin()

        stopMenuAnimationTimer()

        // set up menu titles w/translation
        NoMADMenuLockScreen.title = "Lock Screen".translate
        NoMADMenuChangePassword.title = "NoMADMenuController-ChangePassword".translate

        originalGetCertificateMenu = NoMADMenuGetCertificate
        originalGetCertificateMenuDate = NoMADMenuGetCertificateDate

        // determine if we should show the Password Change Menu Item
        if let showPasswordChange = defaults.string(forKey: Preferences.changePasswordType) {
            if showPasswordChange == "None" {
                NoMADMenuChangePassword.isHidden = true
            }
        }
    }

    // MARK: IBActions

    // Show the login window when the menu item is clicked
    @IBAction func NoMADMenuClickLogIn(_ sender: NSMenuItem) {

        if defaults.bool(forKey: Preferences.useKeychain) {

            // check if there's a last user
            if (defaults.string(forKey: Preferences.lastUser) != "" ) {
                var myPass = ""
                var myErr: String?
                let userPrinc = defaults.string(forKey: Preferences.lastUser)! + "@" + defaults.string(forKey: Preferences.kerberosRealm)!

                do {
                    myPass = try KeychainUtil().findPassword(userPrinc)
                } catch {
                    loginWindow.window!.forceToFrontAndFocus(nil)
                    return
                }

                myErr = KerbUtil().getKerbCredentials(myPass, userPrinc)
                if myErr != nil {
                    myLogger.logit(.base, message:"Error attempting to automatically log in.")
                    loginWindow.window!.forceToFrontAndFocus(nil)
                    return
                } else {
                    myLogger.logit(.base, message:"Automatically logging in.")

                    cliTask("/usr/bin/kswitch -p " +  userPrinc)

                    // fire off the SignInCommand script if there is one
                    if defaults.string(forKey: Preferences.signInCommand) != "" {
                        let myResult = cliTask(defaults.string(forKey: Preferences.signInCommand)!)
                        myLogger.logit(.base, message: myResult)
                        return
                    }
                }
            }
            loginWindow.window!.forceToFrontAndFocus(nil)
        }
    }

    // show the password change window when the menu item is clicked
    @IBAction func NoMADMenuClickChangePassword(_ sender: NSMenuItem) {
        if defaults.string(forKey: Preferences.changePasswordType) != "Kerberos"  {
            PasswordChange().passwordChange()
        } else {
            passwordChangeWindow.window!.forceToFrontAndFocus(nil)
        }
    }

    // kill the Kerb ticket when clicked
    @IBAction func NoMADMenuClickLogOut(_ sender: NSMenuItem) {

        // remove their password from the keychain if they're logging out
        if defaults.string(forKey: Preferences.lastUser) != "" && defaults.bool(forKey: Preferences.useKeychain) {
            var myKeychainItem: SecKeychainItem?
            var myErr: OSStatus
            let serviceName = "NoMAD"
            var passLength: UInt32 = 0
            var passPtr: UnsafeMutableRawPointer? = nil
            let name = defaults.string(forKey: Preferences.lastUser)! + "@" + defaults.string(forKey: Preferences.kerberosRealm)!

            myErr = SecKeychainFindGenericPassword(nil,
                                                   UInt32(serviceName.characters.count),
                                                   serviceName,
                                                   UInt32(name.characters.count),
                                                   name,
                                                   &passLength,
                                                   &passPtr, &myKeychainItem)

            if (myErr == 0) {
                SecKeychainItemDelete(myKeychainItem!)
            } else {
                myLogger.logit(.base, message:"Error deleting Keychain entry.")
            }
        } else {
            loginWindow.window!.forceToFrontAndFocus(nil)
        }

        cliTask("/usr/bin/kdestroy")
        userInformation.connected = false
        lastStatusCheck = Date().addingTimeInterval(-5000)
        updateUserInfo()
    }

    // lock the screen when clicked

    @IBAction func NoMADMenuClickLockScreen(_ sender: NSMenuItem) {
        //  cliTask("/System/Library/CoreServices/Menu\\ Extras/User.menu/Contents/Resources/CGSession -suspend")

        let registry: io_registry_entry_t = IORegistryEntryFromPath(kIOMasterPortDefault, "IOService:/IOResources/IODisplayWrangler")
        let _ = IORegistryEntrySetCFProperty(registry, "IORequestIdle" as CFString!, true as CFTypeRef!)
        IOObjectRelease(registry)

    }

    // gets a cert from the Windows CA

    @IBAction func NoMADMenuClickGetCertificate(_ sender: NSMenuItem) -> Void {

        var myResponse : Int? = nil

        // TODO: check to see if the SSL Certs are trusted, otherwise we'll fail

        // pre-flight to ensure valid URL and template

        var certCATest = defaults.string(forKey: Preferences.x509CA) ?? ""
        let certTemplateTest = defaults.string(forKey: Preferences.template) ?? ""

        if ( certCATest != "" && certTemplateTest != "" ) {

            let lastExpire = defaults.object(forKey: Preferences.lastCertificateExpiration) as! Date ?? Date.distantPast

            if lastExpire.timeIntervalSinceNow > 2592000 {
                let alertController = NSAlert()
                alertController.messageText = "You already have a valid certificate."
                alertController.addButton(withTitle: "Cancel")
                alertController.addButton(withTitle: "Request anyway")

                myResponse = alertController.runModal()

                if myResponse == 1000 {
                    return
                }
            }

            // start the animation

            //startMenuAnimationTimer()

            // check for http://

            if !certCATest.contains("http://") || !certCATest.contains("https://") {
                certCATest = "https://" + certCATest
            }

            let certCARequest = WindowsCATools(serverURL: certCATest, template: certTemplateTest)
            certCARequest.certEnrollment()

        } else {
            let certAlertController = NSAlert()
            certAlertController.messageText = "Please ensure your Certificate Authority settings are correct."
            certAlertController.runModal()
        }

        // stop the animation

        //stopMenuAnimationTimer()
    }


    // opens up a self service portal - this should only be shown if Self Service exists on the machine

    @IBAction func NoMADMenuClickGetSoftware(_ sender: NSMenuItem) {
        guard let selfService = selfService else {
            myLogger.logit(.info, message:"Not using Self Service.")
            return
        }

        switch selfService {
        case .casper:
            NSWorkspace.shared().launchApplication("/Applications/Self Service.app")
        case .lanrev:
            cliTask("/Library/Application\\ Support/LANrev\\ Agent/LANrev\\ Agent.app/Contents/MacOS/LANrev\\ Agent --ShowOnDemandPackages")
        case .munki:
            NSWorkspace.shared().launchApplication("/Applications/Managed Software Center.app")
        default:
            return
        }
    }

    // this enagages help based upon preferences set

    @IBAction func NoMADMenuClickGetHelp(_ sender: NSMenuItem) {
        //startMenuAnimationTimer()
        let myGetHelp = GetHelp()
        myGetHelp.getHelp()
        //stopMenuAnimationTimer()
    }

    // if specified by the preferences, this shows a CLI one-liner

    @IBAction func NoMADMenuClickHiddenItem1(_ sender: NSMenuItem) {
        myLogger.logit(.base, message: "Executing command: " + defaults.string(forKey: Preferences.userCommandTask1)! )
        let myResult = cliTask(defaults.string(forKey: Preferences.userCommandTask1)!)
        myLogger.logit(.base, message:myResult)
    }

    // shows the preferences window

    @IBAction func NoMADMenuClickPreferences(_ sender: NSMenuItem) {
        //preferencesWindow.showWindow(nil)
        preferencesWindow.window!.forceToFrontAndFocus(nil)
    }

    // quit when asked

    @IBAction func NoMADMenuClickQuit(_ sender: NSMenuItem) {
        NSApplication.shared().terminate(self)
    }

    // connect to the Home share if it's available

    @IBAction func homeClicked(_ send: AnyObject) {
        // TODO: I think NSWorkspace can do this...
        cliTask("open smb:" + defaults.string(forKey: Preferences.userHome)!)
    }

    // send copious logs to the console

    @IBAction func NoMADMenuClickSpewLogs(_ sender: AnyObject) {
        myLogger.logit(.base, message:"---- Spew Logs ----")

        myLogger.logit(.base, message:"User information state:")
        myLogger.logit(.base, message:"Realm: " + userInformation.realm)
        myLogger.logit(.base, message:"Domain: " + userInformation.domain)
        myLogger.logit(.base, message:"LDAP Server: " + userInformation.myLDAPServers.currentServer)
        myLogger.logit(.base, message:"LDAP Server Naming Context: " + userInformation.myLDAPServers.defaultNamingContext)
        myLogger.logit(.base, message:"Password expiration default: " + String(userInformation.serverPasswordExpirationDefault))
        myLogger.logit(.base, message:"Password aging: " + String(userInformation.passwordAging))
        myLogger.logit(.base, message:"Connected: " + String(userInformation.connected))
        myLogger.logit(.base, message:"Status: " + userInformation.status)
        myLogger.logit(.base, message:"User short name: " + getConsoleUser())
        myLogger.logit(.base, message:"User long name: " + NSUserName())
        myLogger.logit(.base, message:"User principal: " + userInformation.userPrincipal)
        myLogger.logit(.base, message:"TGT expires: " + String(describing: userInformation.myLDAPServers.tickets.expire))
        myLogger.logit(.base, message:"User password set date: " + String(describing: userInformation.userPasswordSetDate))
        myLogger.logit(.base, message:"User password expire date: " + String(describing: userInformation.userPasswordExpireDate))
        myLogger.logit(.base, message:"User home share: " + userInformation.userHome)

        myLogger.logit(.base, message:"---- User Record ----")
        logEntireUserRecord()
        myLogger.logit(.base, message:"---- Kerberos Tickets ----")
        myLogger.logit(.base, message:(userInformation.myLDAPServers.tickets.returnAllTickets()))

    }

    @IBAction func NoMADMenuClickLogInAlternate(_ sender: AnyObject) {
        //loginWindow.showWindow(nil)
        loginWindow.window!.forceToFrontAndFocus(nil)
    }

    // this will update the menu when it's clicked
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        // Makes all NoMAD windows come to top
        // NSApp.activateIgnoringOtherApps(true)

        if menuItem.title == "Lock Screen".translate {
            updateUserInfo()
        }

        // disable the menus that don't work if you're not logged in

        if self.userInformation.connected == false {

            self.NoMADMenuLogIn.isEnabled = false
            self.NoMADMenuLogIn.title = "NoMADMenuController-LogIn".translate
            self.NoMADMenuLogOut.isEnabled = false
            if (self.NoMADMenuChangePassword != nil) {
                self.NoMADMenuChangePassword.isEnabled = false
            }
            if (self.NoMADMenuGetCertificate != nil)  {
                self.NoMADMenuGetCertificate.isEnabled = false
            }

            // twiddles what needs to be twiddled for connected but not logged in

        } else if self.userInformation.myLDAPServers.tickets.state == false {

            self.NoMADMenuLogIn.isEnabled = true
            self.NoMADMenuLogIn.title = "NoMADMenuController-LogIn".translate
            self.NoMADMenuLogIn.action = #selector(self.NoMADMenuClickLogIn)
            self.NoMADMenuLogOut.isEnabled = false
            if (self.NoMADMenuChangePassword != nil) {
                self.NoMADMenuChangePassword.isEnabled = false
            }
            if (self.NoMADMenuGetCertificate != nil)  {
                self.NoMADMenuGetCertificate.isEnabled = false
            }
        }
        else {
            self.NoMADMenuLogIn.isEnabled = true
            self.NoMADMenuLogIn.title = NSLocalizedString("NoMADMenuController-RenewTickets", comment: "Menu; Button; Renew Tickets")
            self.NoMADMenuLogIn.action = #selector(self.renewTickets)
            self.NoMADMenuLogOut.isEnabled = true
            if (self.NoMADMenuChangePassword != nil) {
                self.NoMADMenuChangePassword.isEnabled = true
            }
            if (self.NoMADMenuGetCertificate != nil)  {
                self.NoMADMenuGetCertificate.isEnabled = true
            }
        }

        if defaults.bool(forKey: Preferences.hidePrefs) {
            self.NoMADMenuPreferences.isEnabled = false
            myLogger.logit(.notice, message:NSLocalizedString("NoMADMenuController-PreferencesDisabled", comment: "Log; Text; Preferences Disabled"))
        }

        return true
    }

    // display a user notifcation

    func showNotification(_ title: String, text: String, date: Date) -> Void {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = text
        //notification.deliveryDate = date
        notification.hasActionButton = true
        notification.actionButtonTitle = "NoMADMenuController-ChangePassword".translate
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }

    // pulls user's entire LDAP record when asked

    func logEntireUserRecord() {
        let myResult = userInformation.myLDAPServers.returnFullRecord("sAMAccountName=" + defaults.string(forKey: Preferences.lastUser)!)
        myLogger.logit(.base, message:myResult)
    }

    // everything to do on a network change

    func doTheNeedfull() {

        //   let qualityBackground = QOS_CLASS_BACKGROUND
        //    let backgroundQueue = dispatch_get_global_queue(qualityBackground, 0)
        //dispatch_async(myWorkQueue, {

        if ( self.userInformation.myLDAPServers.getDomain() == "not set" ) {
            //self.userInformation.myLDAPServers.tickets.getDetails()
            self.userInformation.myLDAPServers.currentDomain = defaults.string(forKey: Preferences.aDDomain)!
        }

        autoLogin()

        self.updateUserInfo()
        // })
    }

    // simple function to renew tickets

    func renewTickets(){
        cliTask("/usr/bin/kinit -R")
        userInformation.myLDAPServers.tickets.getDetails()
        if defaults.bool(forKey: Preferences.verbose) == true {
            myLogger.logit(.base, message:"Renewing tickets.")
        }
    }

    func animateMenuItem() {
        if statusItem.image == iconOnOn {
            statusItem.image = iconOffOff
        } else {
            statusItem.image = iconOnOn
        }
    }

    // function to see if we should autologin and then proceede accordingly
    func autoLogin() {
        // only autologin if 1) we're set to use the keychain, 2) we have don't already have a Kerb ticket and 3) we can contact the LDAP servers
        if (defaults.bool(forKey: Preferences.useKeychain)) && !userInformation.myLDAPServers.tickets.state && userInformation.myLDAPServers.currentState {
            myLogger.logit(.info, message: "Attempting to auto-login")
            NoMADMenuClickLogIn(NoMADMenuLogIn)
        }
    }

    // function to start the menu throbbing
    func startMenuAnimationTimer() {
        menuAnimationTimer = Timer(timeInterval: 1, target: self, selector: #selector(animateMenuItem), userInfo: nil, repeats: true)
        statusItem.menu = NSMenu()
        RunLoop.current.add(menuAnimationTimer, forMode: RunLoopMode.defaultRunLoopMode)
        menuAnimationTimer.fire()
    }

    func stopMenuAnimationTimer() {
        menuAnimationTimer.invalidate()
    }

    // function to configure Chrome

    func configureChrome() {
        cliTask("defaults write com.google.Chrome AuthServerWhiteList \"*." + defaults.string(forKey: Preferences.aDDomain)! + "\"")
        cliTask("defaults write com.google.Chrome AuthNegotiateDelegateWhitelist \"*." + defaults.string(forKey: Preferences.aDDomain)! + "\"")
    }

    // update the user info and build the actual menu

    func updateUserInfo() {

        myLogger.logit(.base, message:"Updating User Info")


        // make sure the domain we're using is the domain we should be using

        if ( userInformation.myLDAPServers.getDomain() != defaults.string(forKey: Preferences.aDDomain)!) {
            userInformation.myLDAPServers.setDomain(defaults.string(forKey: Preferences.aDDomain)!)
        }

        // check for network reachability

        let host = defaults.string(forKey: Preferences.aDDomain)
        let myReach = SCNetworkReachabilityCreateWithName(nil, host!)
        var flag = SCNetworkReachabilityFlags.reachable

        if !SCNetworkReachabilityGetFlags(myReach!, &flag) {
            myLogger.logit(.base, message: "Can't determine network reachability.")
            lastStatusCheck = Date()
        }

        if (flag.rawValue != UInt32(kSCNetworkFlagsReachable)) {
            // network isn't reachable
            myLogger.logit(.base, message: "Network is not reachable, delaying lookups.")
            lastStatusCheck = Date()
        }

        if abs(lastStatusCheck.timeIntervalSinceNow) > 3 {

            // through the magic of code blocks we'll update in the background
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short

            myWorkQueue.async(execute: {
                //self.startMenuAnimationTimer()

                self.userInformation.getUserInfo()

                //self.menuAnimationTimer.invalidate()

                DispatchQueue.main.sync(execute: { () -> Void in

                    // build the menu


                    self.statusItem.menu = self.NoMADMenu

                    // set the menu icon
                    if self.userInformation.status == "Connected" {
                        self.statusItem.image = self.iconOnOff
                        // we do this twice b/c doing it only once seems to make it less than full width
                        self.statusItem.title = self.userInformation.status.translate
                        self.statusItem.title = self.userInformation.status.translate

                        // if we're not logged in we disable some options

                        self.statusItem.toolTip = dateFormatter.string(from: self.userInformation.userPasswordExpireDate as Date)
                        self.NoMADMenuTicketLife.title = "Not logged in."

                    } else if self.userInformation.status == "Logged In" && self.userInformation.myLDAPServers.tickets.state {
                        self.statusItem.image = self.iconOnOn

                        // if we're logged in we enable some options

                        // self.NoMADMenuLogOut.enabled = true
                        // self.NoMADMenuChangePassword.enabled = true

                        if self.userInformation.passwordAging {

                            self.statusItem.toolTip = dateFormatter.string(from: self.userInformation.userPasswordExpireDate as Date)
                            self.NoMADMenuTicketLife.title = dateFormatter.string(from: self.userInformation.myLDAPServers.tickets.expire as Date) + " " + self.userInformation.myLDAPServers.currentServer

                            let daysToGo = Int(abs(self.userInformation.userPasswordExpireDate.timeIntervalSinceNow)/86400)
                            // we do this twice b/c doing it only once seems to make it less than full width
                            if Int(daysToGo) > 4 {
                                self.statusItem.title = (String(daysToGo) + "d" )
                                self.statusItem.title = (String(daysToGo) + "d" )
                            } else {

                                let myMutableString = NSMutableAttributedString(string: String(daysToGo) + "d")
                                myMutableString.addAttribute(NSForegroundColorAttributeName, value: NSColor.red, range: NSRange(location: 0, length: 2))
                                self.statusItem.attributedTitle = myMutableString
                                self.statusItem.attributedTitle = myMutableString
                            }
                        } else {

                            // we do this twice b/c doing it only once seems to make it less than full width
                            self.statusItem.title = ""
                            self.statusItem.title = ""
                            self.NoMADMenuTicketLife.title = dateFormatter.string(from: self.userInformation.myLDAPServers.tickets.expire as Date) + " " + self.userInformation.myLDAPServers.currentServer
                        }
                    } else {
                        self.statusItem.image = self.iconOffOff

                        // we do this twice b/c doing it only once seems to make it less than full width
                        self.statusItem.title = self.userInformation.status.translate
                        self.statusItem.title = self.userInformation.status.translate
                    }

                    if ( self.userInformation.userPrincipalShort != "No User" ) {
                        self.NoMADMenuUserName.title = self.userInformation.userPrincipalShort
                    } else {
                        self.NoMADMenuUserName.title = defaults.string(forKey: Preferences.lastUser) ?? "No User"
                    }

                    if ( !defaults.bool(forKey: Preferences.userAging) ) && ( defaults.string(forKey: Preferences.lastUser) != "" ) {
                        self.NoMADMenuPasswordExpires.title = "Password does not expire."
                    } else if ( defaults.string(forKey: Preferences.lastUser)) != "" {
                        let myDaysToGo = String(abs(((defaults.object(forKey: Preferences.lastPasswordExpireDate)! as AnyObject).timeIntervalSinceNow)!)/86400)
                        //self.NoMADMenuPasswordExpires.title = "Password expires in: " + myDaysToGo.componentsSeparatedByString(".")[0] + " days"
                        let title = String.localizedStringWithFormat(
                            NSLocalizedString("NoMADMenuController-PasswordExpiresInDays", comment: "Menu Text; Password expires in: %@ days"),
                            myDaysToGo.components(separatedBy: ".")[0]
                        )
                        self.NoMADMenuPasswordExpires.title = title
                    } else {
                        self.NoMADMenuPasswordExpires.title = ""
                    }

                    let futureDate = Date()
                    futureDate.addingTimeInterval(300)

                    // add shortname into the defaults

                    defaults.set(self.userInformation.userPrincipalShort, forKey: Preferences.userShortName)

                    // if a user command is specified, show it, otherwise hide the menu item

                    if ( defaults.string(forKey: Preferences.userCommandName1) != "" ) {
                        self.NoMADMenuHiddenItem1.isEnabled = true
                        self.NoMADMenuHiddenItem1.isHidden = false
                        self.NoMADMenuHiddenItem1.title = defaults.string(forKey: Preferences.userCommandName1)!
                        self.NoMADMenuHiddenItem1.keyEquivalent = defaults.string(forKey: Preferences.userCommandHotKey1)!
                    } else  {
                        self.NoMADMenuHiddenItem1.isHidden = true
                        self.NoMADMenuHiddenItem1.isEnabled = false
                    }

                    // add home directory menu item

                    if self.userInformation.connected && defaults.integer(forKey: Preferences.showHome) == 1 {

                        if ( self.userInformation.userHome != "" && self.NoMADMenu.items.contains(self.NoMADMenuHome) == false ) {
                            self.NoMADMenuHome.title = "Home Sharepoint"
                            self.NoMADMenuHome.action = #selector(self.homeClicked)
                            self.NoMADMenuHome.target = self.NoMADMenuLogOut.target
                            self.NoMADMenuHome.isEnabled = true
                            // should key this off of the position of the Preferences menu
                            let prefIndex = self.NoMADMenu.index(of: self.NoMADMenuPreferences)
                            self.NoMADMenu.insertItem(self.NoMADMenuHome, at: (prefIndex - 1 ))
                        } else if self.userInformation.userHome != "" && self.NoMADMenu.items.contains(self.NoMADMenuHome) {
                            self.NoMADMenuHome.title = "Home Sharepoint"
                            self.NoMADMenuHome.action = #selector(self.homeClicked)
                            self.NoMADMenuHome.target = self.NoMADMenuLogOut.target
                            self.NoMADMenuHome.isEnabled = true
                        } else if self.NoMADMenu.items.contains(self.NoMADMenuHome) {
                            self.NoMADMenu.removeItem(self.NoMADMenuHome)

                        }

                        // Share Mounter setup taken out for now

                        //self.myShareMounter.asyncMountShare("smb:" + defaults.stringForKey("UserHome")!)
                        //self.myShareMounter.mount()
                    }
                })

                // check if we need to renew the ticket

                if defaults.integer(forKey: Preferences.renewTickets) == 1 && self.userInformation.status == "Logged In" && ( abs(self.userInformation.myLDAPServers.tickets.expire.timeIntervalSinceNow) >= Double(defaults.integer(forKey: Preferences.secondsToRenew))) {
                    self.renewTickets()
                }

                // check if we need to notify the user


                // reset the counter if the password change is over the default

                if ( abs(self.userInformation.userPasswordExpireDate.timeIntervalSinceNow) < Double(defaults.integer(forKey: Preferences.passwordExpireAlertTime)) && self.userInformation.status == "Logged In" ) && self.userInformation.passwordAging {

                    if ( abs(self.userInformation.userPasswordExpireDate.timeIntervalSinceNow) < Double(defaults.integer(forKey: Preferences.lastPasswordWarning)) ) {
                        if ( abs(self.userInformation.userPasswordExpireDate.timeIntervalSinceNow) > Double(345600) ) {
                            // expire is between default and four days so notify once a day
                            self.showNotification("Password about to expire!", text: "Your network password is about to expire on " + dateFormatter.string(from: self.userInformation.userPasswordExpireDate as Date), date: Date())
                            defaults.set((abs(self.userInformation.userPasswordExpireDate.timeIntervalSinceNow) - 86400 ), forKey: Preferences.lastPasswordWarning)
                        } else if ( abs(self.userInformation.userPasswordExpireDate.timeIntervalSinceNow) > Double(86400) ) {
                            // expire is between 4 days and 1 day so notifiy every 12 hours
                            self.showNotification("Password about to expire!", text: "Your network password is about to expire on " + dateFormatter.string(from: self.userInformation.userPasswordExpireDate as Date), date: Date())
                            defaults.set( (abs(self.userInformation.userPasswordExpireDate.timeIntervalSinceNow) - 23200 ), forKey: Preferences.lastPasswordWarning)
                        } else {
                            // expire is less than 1 day so notifiy every hour
                            self.showNotification("Password about to expire!", text: "Your network password is about to expire on " + dateFormatter.string(from: self.userInformation.userPasswordExpireDate as Date), date: Date())
                            defaults.set((abs(self.userInformation.userPasswordExpireDate.timeIntervalSinceNow) - 3600 ), forKey: Preferences.lastPasswordWarning)
                        }
                    }
                } else {
                    defaults.set(Double(defaults.integer(forKey: Preferences.passwordExpireAlertTime) ?? 1296000), forKey: Preferences.lastPasswordWarning)
                }
                
                // remove the Get Certificate menu if not needed
                // add it back in when it is needed
                
                if defaults.string(forKey: Preferences.x509CA) == "" && self.NoMADMenuGetCertificate != nil {
                    self.NoMADMenu.removeItem(self.NoMADMenuGetCertificate)
                    self.NoMADMenu.removeItem(self.NoMADMenuGetCertificateDate)
                    self.NoMADMenuGetCertificate = nil
                } else if defaults.string(forKey: Preferences.x509CA) != "" && self.NoMADMenuGetCertificate == nil{
                    self.NoMADMenuGetCertificate = self.originalGetCertificateMenu
                    self.NoMADMenuGetCertificateDate = self.originalGetCertificateMenuDate
                    let lockIndex = self.NoMADMenu.index(of: self.NoMADMenuLockScreen)
                    self.NoMADMenu.insertItem(self.NoMADMenuGetCertificate, at: (lockIndex + 1 ))
                    self.NoMADMenu.insertItem(self.NoMADMenuGetCertificateDate, at: (lockIndex + 2 ))
                }
                
            })
            
            // mark the time and clear the update scheduled flag
            
            lastStatusCheck = Date()
            updateScheduled = false
            
            if let expireDate = defaults.object(forKey: Preferences.lastCertificateExpiration) as? Date {
                if expireDate != Date.distantPast {
                    NoMADMenuGetCertificateDate.title = dateFormatter.string(from: expireDate)
                } else {
                    NoMADMenuGetCertificateDate.title = "No Certs"
                }
            }
        } else {
            myLogger.logit(.info, message:"Time between system checks is too short, delaying")
            if ( !updateScheduled ) {
                Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(updateUserInfo), userInfo: nil, repeats: false)
                updateScheduled = true
            }
        }
    }
}
