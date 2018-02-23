//
//  NoMADMenuController.swift
//  NoMAD
//
//  Created by Joel Rennich on 7/8/16.
//  Copyright © 2016 Orchard & Grove Inc. All rights reserved.
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

// for delegates
let preferencesWindow = PreferencesWindow()
let passwordChangeWindow = PasswordChangeWindow()
let loginWindow = LoginWindow()

class NoMADMenuController: NSObject, LoginWindowDelegate, PasswordChangeDelegate, PreferencesWindowDelegate, NSMenuDelegate, NSUserNotificationCenterDelegate {
    @objc
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
    @IBOutlet weak var NoMADMenuAbout: NSMenuItem!
    @IBOutlet weak var NoMADMenuQuit: NSMenuItem!
    @IBOutlet weak var NoMADMenuSpewLogs: NSMenuItem!
    @IBOutlet weak var NoMADMenuGetCertificateDate: NSMenuItem!
    @IBOutlet weak var NoMADMenuTicketLife: NSMenuItem!
    @IBOutlet weak var NoMADMenuLogInAlternate: NSMenuItem!
    @IBOutlet weak var NoMADMenuSeperatorSoftwareAndHelp: NSMenuItem!
    @IBOutlet weak var NoMADMenuSeperatorTicketLife: NSMenuItem!
    
    @objc let NoMADMenuHome = NSMenuItem()
    @objc let myShareMenuItem = NSMenuItem()
    @objc let myActionsMenu = NSMenuItem()
    
    // menu bar icons
    
    @objc var iconOnOn = NSImage()
    @objc var iconOnOff = NSImage()
    @objc var iconOffOff = NSImage()
    
    @objc var iconAltOnOn = NSImage()
    @objc var iconAltOnOff = NSImage()
    @objc var iconAltOffOff = NSImage()
    
    @objc var myIconOn = NSImage()
    @objc var myIconOff = NSImage()
    
    @objc var myIconOnDark = NSImage()
    @objc var myIconOffDark = NSImage()
    
    @objc let userNotificationCenter = NSUserNotificationCenter.default
    
    @objc var originalGetCertificateMenu : NSMenuItem!
    @objc var originalGetCertificateMenuDate : NSMenuItem!
    
    let userInformation = UserInformation()
    
    @objc var lastStatusCheck = Date().addingTimeInterval(-5000)
    @objc var firstRun = true
    @objc var updateScheduled = false
    @objc var updateRunning = false
    @objc var menuAnimated = false
    
    @objc let myShareMounter = ShareMounter()
    
    @objc var PKINIT = false
    
    //let myShareMounter = ShareMounter()
    
    @objc var menuAnimationTimer = Timer()
    @objc var delayTimer = Timer()
    
    @objc let myWorkQueue = DispatchQueue(label: "com.trusourcelabs.NoMAD.background_work_queue", attributes: [])
    @objc let shareMounterQueue = DispatchQueue(label: "com.trusourcelabs.NoMAD.shareMounting", attributes: [])
    @objc let reachCheckQueue = DispatchQueue(label: "com.trusourcelabs.NoMAD.reachability", attributes: [])
    
    var selfService: SelfServiceType?
    
    @objc let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    @objc let PKINITMenuItem = NSMenuItem()
    
    let myKeychainutil = KeychainUtil()
    
    @objc var signInOffered = false
    
    /// Fired when the menu loads the first time
    override func awakeFromNib() {
        
        myLogger.logit(.base, message:"---Starting NoMAD---")
        
        // check for locked keychains
        
        if self.myKeychainutil.checkLockedKeychain() && defaults.bool(forKey: Preferences.lockedKeychainCheck) {
            // notify on the keychain
            myLogger.logit(.base, message: "Keychain is locked, showing notification.")
            keychainMinder.window?.forceToFrontAndFocus(nil)
        }
        
        //        while myKeychainutil.checkLockedKeychain() && defaults.bool(forKey: Preferences.lockedKeychainCheck) {
        //            // pause until Keychain is fixed
        //            myLogger.logit(.base, message: "Waiting for keychain to unlock.")
        //            RunLoop.current.run(mode: RunLoopMode.defaultRunLoopMode, before: Date.distantFuture)
        //        }
        
        let defaultPreferences = NSDictionary(contentsOf: Bundle.main.url(forResource: "DefaultPreferences", withExtension: "plist")!)
        defaults.register(defaults: defaultPreferences as! [String : Any])
        
        if !defaults.bool(forKey: Preferences.dontShowWelcome) && ProcessInfo().operatingSystemVersion.minorVersion > 10 {
            welcome.window?.forceToFrontAndFocus(nil)
        }
        
        // AppleEvents
        
        LSSetDefaultHandlerForURLScheme("nomad" as CFString, "com.trusourcelabs.NoMAD" as CFString)
        let eventManager = NSAppleEventManager.shared()
        
        eventManager.setEventHandler(self, andSelector: #selector(handleAppleEvent), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
        
        // set up shares
        
        // only do this if shares are available
        
        shareMounterMenu.updateShares(connected: self.userInformation.connected)
        
        // load up the actions
        
        nActionMenu.load()
        nActionMenu.updateActions(self.userInformation.connected)
        
        print(defaults.integer(forKey: Preferences.autoRenewCert))
        
        // set up Icons - we need 2 sets of 2 for light and dark modes
        
        if defaults.string(forKey: Preferences.iconOn) != nil {
            myIconOn = NSImage.init(contentsOfFile: defaults.string(forKey: Preferences.iconOn)!)!
        } else {
            myIconOn = NSImage(named: NSImage.Name(rawValue: "NoMAD-statusicon-on-on"))!
        }
        
        if defaults.string(forKey: Preferences.iconOff) != nil {
            myIconOff = NSImage.init(contentsOfFile: defaults.string(forKey: Preferences.iconOff)!)!
        } else {
            myIconOff = NSImage(named: NSImage.Name(rawValue: "NoMAD-statusicon-off-off"))!
        }
        
        if defaults.string(forKey: Preferences.iconOnDark) != nil {
            myIconOnDark = NSImage.init(contentsOfFile: defaults.string(forKey: Preferences.iconOnDark)!)!
        } else {
            myIconOnDark = NSImage(named: NSImage.Name(rawValue: "NoMAD-LogoAlternate-on"))!
        }
        
        if defaults.string(forKey: Preferences.iconOffDark) != nil {
            myIconOffDark = NSImage.init(contentsOfFile: defaults.string(forKey: Preferences.iconOffDark)!)!
        } else {
            myIconOffDark = NSImage(named: NSImage.Name(rawValue: "NoMAD-LogoAlternate-off"))!
        }
        
        // check for Dark Mode
        
        if UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?["AppleInterfaceStyle"] == nil {
            if !defaults.bool(forKey: Preferences.caribouTime) {
                iconOnOn = myIconOn
                iconOnOff = NSImage(named: NSImage.Name(rawValue: "NoMAD-statusicon-on-off"))!
                iconOffOff = myIconOff
                
                // and the alternates
                
                iconAltOnOn = myIconOnDark
                iconAltOnOff = myIconOffDark
                iconAltOffOff = myIconOffDark
                
            } else {
                iconOnOn = NSImage(named: NSImage.Name(rawValue: "NoMAD-Caribou-on"))!
                iconOffOff = NSImage(named: NSImage.Name(rawValue: "NoMAD-Caribou-off"))!
                
                iconAltOffOff = NSImage(named: NSImage.Name(rawValue: "NoMAD-Caribou-dark-off"))!
                iconAltOnOn = NSImage(named: NSImage.Name(rawValue: "NoMAD-Caribou-dark-on"))!
            }
        } else {
            if !defaults.bool(forKey: Preferences.caribouTime) {
                iconOnOn = myIconOnDark
                //iconOnOff = NSImage(named: "NoMAD-statusicon-on-off")
                iconOffOff = myIconOffDark
                
                iconAltOnOn = myIconOn
                iconAltOffOff = myIconOff
                
            } else {
                iconOnOn = NSImage(named: NSImage.Name(rawValue: "NoMAD-Caribou-dark-on"))!
                iconOffOff = NSImage(named: NSImage.Name(rawValue: "NoMAD-Caribou-dark-off"))!
                
                iconAltOffOff = NSImage(named: NSImage.Name(rawValue: "NoMAD-Caribou-off"))!
                iconAltOnOn = NSImage(named: NSImage.Name(rawValue: "NoMAD-Caribou-on"))!
            }
        }
        
        // Register for update notifications.
        NotificationCenter.default.addObserver(self, selector: #selector(doTheNeedfull), name: NSNotification.Name(rawValue: "menu.nomad.NoMAD.updateNow"), object: nil)
        
        DistributedNotificationCenter.default.addObserver(self, selector: #selector(interfaceModeChanged), name: NSNotification.Name(rawValue: "AppleInterfaceThemeChangedNotification"), object: nil)
        
        loginWindow.delegate = self
        passwordChangeWindow.delegate = self
        preferencesWindow.delegate = self
        userNotificationCenter.delegate = self
        
        // Allows us to force windows to show when menu clicked.
        self.NoMADMenu.delegate = self
        
        // see if we should auto-configure
        setDefaults()
        
        // double check that we have a Kerberos Realm
        
        if defaults.string(forKey: Preferences.kerberosRealm) == "" || defaults.string(forKey: Preferences.kerberosRealm) == nil {
            defaults.set(defaults.string(forKey: Preferences.aDDomain)?.uppercased(), forKey: Preferences.kerberosRealm)
        }
        
        // if no preferences are set, we show the preferences pane
        if (defaults.string(forKey: Preferences.aDDomain) == "" ) {
            preferencesWindow.window!.forceToFrontAndFocus(nil)
        } else {
            doTheNeedfull()
        }
        
        // Add a PKINIT menu if PKINITer is in the bundle
        
        if findPKINITer() {
            
            // we have PKINITer so build the menu
            // TODO: translate these items
            
            PKINITMenuItem.title = "NoMADMenuController-SmartcardSignIn".translate
            PKINITMenuItem.toolTip = "NoMADMenuController-SignInWithSmartcard".translate
            PKINITMenuItem.action = #selector(smartcardSignIn)
            PKINITMenuItem.target = self
            PKINITMenuItem.isEnabled = true
            
            // add the menu
            
            NoMADMenu.insertItem(PKINITMenuItem, at: (NoMADMenu.index(of: self.NoMADMenuSeperatorTicketLife) + 1))
            
        }
        
        // set up some default menu items
        
        NoMADMenuPasswordExpires.title = defaults.string(forKey: Preferences.menuPasswordExpires) ?? ""
        
        // hide Sign out if asked
        
        if defaults.bool(forKey: Preferences.hideSignOut) {
            NoMADMenuLogOut.isHidden = true
        }
        
        // find out if a Self Service Solution exists - hide the menu item if it's not there
        myLogger.logit(.notice, message:"Looking for Self Service applications")
        
        if !defaults.bool(forKey: Preferences.hideGetSoftware) {
            if let discoveredService = SelfServiceManager().discoverSelfService() {
                selfService = discoveredService
                if let menuTitle = defaults.string(forKey: Preferences.menuGetSoftware) {
                    NoMADMenuGetSoftware.title = menuTitle
                }
            } else {
                NoMADMenuGetSoftware.isHidden = true
                myLogger.logit(.info, message:"Not using Self Service.")
            }
        } else {
            NoMADMenuGetSoftware.isHidden = true
            myLogger.logit(.info, message:"Not using Self Service.")
        }
        
        if defaults.bool(forKey: Preferences.hideHelp) {
            NoMADMenuGetHelp.isHidden = true
            myLogger.logit(.info, message:"Not using Get Help.")
        } else {
            if let menuTitle = defaults.string(forKey: Preferences.menuGetHelp) {
                NoMADMenuGetHelp.title = menuTitle
            }
        }
        
        // hide divider if both getHelp and getSoftware are hidden
        
        if (NoMADMenuGetHelp.isHidden) && (NoMADMenuGetSoftware.isHidden) {
            NoMADMenuSeperatorSoftwareAndHelp.isHidden = true
        }
        
        // Hide Renew Tickets
        
        // wait for any updates to finish
        
        //while updateRunning {
        //RunLoop.current.run(mode: RunLoopMode.defaultRunLoopMode, before: Date.distantFuture)
        //}
        
        // configure Chrome
        
        if defaults.bool(forKey: Preferences.configureChrome) {
            configureChrome()
        }
        
        // hide About if told to
        
        if defaults.bool(forKey: Preferences.hideAbout) {
            NoMADMenuAbout.isHidden = true
        }
        
        // change the About name if we need to
        
        NoMADMenuAbout.title = defaults.string(forKey: Preferences.menuAbout) ?? "About"
        
        // hide the Quit button if told to
        
        if CommandLine.arguments.contains("-noquit") || defaults.bool(forKey: Preferences.hideQuit) {
            NoMADMenuQuit.isHidden = true
        }
        
        // check if we need to clean certs
        
        if defaults.bool(forKey: Preferences.cleanCerts) {
            myWorkQueue.async(execute: {
                myLogger.logit(.debug, message: "Starting Cert clean")
            KeychainUtil().cleanCerts()
            })
        }
        
        // check for a Kerberos preference file
        
        configureKerbPefs()
        
        firstRun = false
        
        // set up menu titles w/translation
        NoMADMenuLockScreen.title = "Lock Screen".translate
        NoMADMenuChangePassword.title = defaults.string(forKey: Preferences.menuChangePassword) ?? "NoMADMenuController-ChangePassword".translate
        
        if defaults.bool(forKey: Preferences.hideLockScreen) || ProcessInfo().operatingSystemVersion.minorVersion > 12 {
            NoMADMenuLockScreen.isHidden = true
        }
        
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
        
        DispatchQueue.main.async {
        
        if defaults.bool(forKey: Preferences.useKeychain) && (defaults.string(forKey: Preferences.lastUser) != "" ) {
            
            // check if there's a last user
            var myPass = ""
            var myErr: String?
            let userPrinc = defaults.string(forKey: Preferences.lastUser)! + "@" + defaults.string(forKey: Preferences.kerberosRealm)!
            
            do {
                myPass = try KeychainUtil().findPassword(userPrinc)
            } catch {
                loginWindow.window!.forceToFrontAndFocus(nil)
                return
            }
            
            let myKerbUtil = KerbUtil()
            myErr = myKerbUtil.getKerbCredentials(myPass, userPrinc)
            
            while ( !myKerbUtil.finished ) {
                RunLoop.current.run(mode: RunLoopMode.defaultRunLoopMode, before: Date.distantFuture)
            }
            
            if myErr == nil {
                myLogger.logit(.base, message:"Automatically logged in.")
                
                let _ = cliTask("/usr/bin/kswitch -p " +  userPrinc)
                
                // fire off the SignInCommand script if there is one
                if defaults.string(forKey: Preferences.signInCommand) != "" {
                    let myResult = cliTask(defaults.string(forKey: Preferences.signInCommand)!)
                    myLogger.logit(.base, message: myResult)
                }
                return
            } else if (myErr?.contains("Preauthentication failed"))! {
                myLogger.logit(.base, message:"Autologin password error.")
                // password failed, let's delete it so as to not fail again
                var myKeychainItem: SecKeychainItem?
                var myErr: OSStatus
                let serviceName = "NoMAD"
                var passLength: UInt32 = 0
                var passPtr: UnsafeMutableRawPointer? = nil
                let name = defaults.string(forKey: Preferences.lastUser)! + "@" + defaults.string(forKey: Preferences.kerberosRealm)!
                
                myErr = SecKeychainFindGenericPassword(nil,
                                                       UInt32(serviceName.count),
                                                       serviceName,
                                                       UInt32(name.count),
                                                       name,
                                                       &passLength,
                                                       &passPtr, &myKeychainItem)
                if (myErr == 0) {
                    SecKeychainItemDelete(myKeychainItem!)
                } else {
                    myLogger.logit(.base, message:"Error deleting Keychain entry.")
                }
                // now show the window
                loginWindow.window!.forceToFrontAndFocus(nil)
                return
            } else  {
                myLogger.logit(.base, message:"Error attempting to automatically log in.")
                loginWindow.window!.forceToFrontAndFocus(nil)
                return
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
                                                   UInt32(serviceName.count),
                                                   serviceName,
                                                   UInt32(name.count),
                                                   name,
                                                   &passLength,
                                                   &passPtr, &myKeychainItem)
            
            if (myErr == 0) {
                SecKeychainItemDelete(myKeychainItem!)
            } else {
                myLogger.logit(.base, message:"Error deleting Keychain entry.")
            }
        } else {
            //loginWindow.window!.forceToFrontAndFocus(nil)
        }
        
        let _ = cliTask("/usr/bin/kdestroy")
        
        // fire off the SignOutCommand script if there is one
        
        if let command = defaults.string(forKey: Preferences.signOutCommand) {
            let myResult = cliTask(command)
            myLogger.logit(LogLevel.base, message: myResult)
        }
        userInformation.connected = false
        lastStatusCheck = Date().addingTimeInterval(-5000)
        updateUserInfo()
    }
    
    // Sleep the screen when clicked
    @IBAction func NoMADMenuClickLockScreen(_ sender: NSMenuItem) {
        
        lockScreenImmediate()
        
        return

        // Commented out unreachable code
//        let registry: io_registry_entry_t = IORegistryEntryFromPath(kIOMasterPortDefault, "IOService:/IOResources/IODisplayWrangler")
//        let _ = IORegistryEntrySetCFProperty(registry, "IORequestIdle" as CFString!, true as CFTypeRef!)
//        IOObjectRelease(registry)

    }
    
    @objc func lockScreenImmediate() -> Void {
        
        //
        // Thanks to @ftiff for this
        // www.github.com/ftiff
        //
        
        // Note: Private -- Do not use!
        // http://stackoverflow.com/questions/34669958/swift-how-to-call-a-c-function-loaded-from-a-dylib
        
        let libHandle = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_LAZY)
        let sym = dlsym(libHandle, "SACLockScreenImmediate")
        typealias myFunction = @convention(c) () -> Void
        let SACLockScreenImmediate = unsafeBitCast(sym, to: myFunction.self)
        SACLockScreenImmediate()
    }
    
    // gets a cert from the Windows CA
    @IBAction func NoMADMenuClickGetCertificate(_ sender: NSMenuItem) -> Void {
        getCert(true)
    }
    
    
    // opens up a self service portal - this should only be shown if Self Service exists on the machine
    @IBAction func NoMADMenuClickGetSoftware(_ sender: NSMenuItem) {
        guard let selfService = selfService else {
            myLogger.logit(.info, message:"Not using Self Service.")
            return
        }
        
        switch selfService {
        case .casper:
            NSWorkspace.shared.launchApplication("/Applications/Self Service.app")
        case .lanrev:
            let _ = cliTask("/Library/Application\\ Support/LANrev\\ Agent/LANrev\\ Agent.app/Contents/MacOS/LANrev\\ Agent --ShowOnDemandPackages")
        case .munki:
            NSWorkspace.shared.launchApplication("/Applications/Managed Software Center.app")
        case .custom:
            let _ = cliTask("/usr/bin/open " + defaults.string(forKey: Preferences.selfServicePath)!)
        }
    }
    
    // this enagages help based upon preferences set
    @IBAction func NoMADMenuClickGetHelp(_ sender: NSMenuItem) {
        //startMenuAnimationTimer()
        GetHelp().getHelp()
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
        preferencesWindow.window!.forceToFrontAndFocus(nil)
    }
    
    @IBAction func NoMADMenuClickAbout(_ sender: Any) {
        welcome.window?.forceToFrontAndFocus(nil)
    }
    
    // quit when asked
    @IBAction func NoMADMenuClickQuit(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(self)
    }
    
    // show PKINITer when asked
    
    @objc func smartcardSignIn() {
        launchPKINITer()
    }
    
    @objc func getCert(_ alerts: Bool) {
        
        var myResponse: Int?
        
        // TODO: check to see if the SSL Certs are trusted, otherwise we'll fail
        
        // pre-flight to ensure valid URL and template
        
        var certCATest = defaults.string(forKey: Preferences.x509CA) ?? ""
        let certTemplateTest = defaults.string(forKey: Preferences.template) ?? ""
        
        if ( certCATest != "" && certTemplateTest != "" ) {
            
            let lastExpireTemp = defaults.object(forKey: Preferences.lastCertificateExpiration) ?? ""
            var lastExpire: Date?
            
            if (String(describing: lastExpireTemp)) == "" {
                lastExpire = Date.distantPast as Date
            } else {
                lastExpire = lastExpireTemp as? Date
            }
            
            if (lastExpire?.timeIntervalSinceNow)! > 2592000 {
                if alerts {
                    let alertController = NSAlert()
                    alertController.messageText = "ValidCertificate".translate
                    alertController.addButton(withTitle: "Cancel".translate)
                    alertController.addButton(withTitle: "RequestAnyway".translate)
                    
                    myResponse = alertController.runModal().rawValue
                    
                    if myResponse == 1000 {
                        return
                    }
                } else {
                    return
                }
            }
            
            // start the animation
            
            //startMenuAnimationTimer()
            
            // check for http://
            
            if !certCATest.contains("http://") || !certCATest.contains("https://") {
                certCATest = "https://" + certCATest
            }
            
            // preflight that there aren't SSL issues
            var caTestWait = true
            var caSSLTest = true
            myWorkQueue.async(execute: {
                self.testSite(caURL: certCATest, completionHandler: { (data, response, error) in
                    
                    if (error != nil) {
                        caSSLTest = false
                    }
                    caTestWait = false
                }
                )})
            
            while caTestWait {
                RunLoop.current.run(mode: RunLoopMode.defaultRunLoopMode, before: Date.distantFuture)
                myLogger.logit(.debug, message: "Waiting for CA test to complete.")
            }
            
            if !caSSLTest {
                let certAlertController = NSAlert()
                certAlertController.messageText = "CertConnectionError".translate
                if alerts {
                    certAlertController.runModal()
                } else {
                    myLogger.logit(.base, message: "Automatic cert error: " + "CertConnectionError".translate)
                }
            } else {
                
                let certCARequest = WindowsCATools(serverURL: certCATest, template: certTemplateTest)
                let _ = certCARequest.certEnrollment()
            }
            
        } else {
            let certAlertController = NSAlert()
            certAlertController.messageText = "CAConfigError".translate
            if alerts {
                certAlertController.runModal()
            } else {
                myLogger.logit(.base, message: "Automatic cert error: " + "CAConfigError".translate)
            }
            
        }
    }
    
    // connect to the Home share if it's available
    @IBAction func homeClicked(_ send: AnyObject) {
        // TODO: I think NSWorkspace can do this...
        let _ = cliTask("open smb:" + defaults.string(forKey: Preferences.userHome)!)
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
        //myLogger.logit(.base, message:"TGT expires: " + String(describing: userInformation.myLDAPServers.tickets.expire))
        myLogger.logit(.base, message:"User password set date: " + String(describing: userInformation.userPasswordSetDate))
        myLogger.logit(.base, message:"User password expire date: " + String(describing: userInformation.userPasswordExpireDate))
        myLogger.logit(.base, message:"User home share: " + userInformation.userHome)
        
        myLogger.logit(.base, message:"---- User Record ----")
        logEntireUserRecord()
        myLogger.logit(.base, message:"---- Kerberos Tickets ----")
        //myLogger.logit(.base, message:(userInformation.myLDAPServers.tickets.returnTickets()))
        
    }
    
    @IBAction func NoMADMenuClickLogInAlternate(_ sender: AnyObject) {
        //loginWindow.showWindow(nil)
        
        // set flag to ignore pssword sync
        loginWindow.window!.forceToFrontAndFocus(nil)
        loginWindow.suppressPasswordChange = true
    }
    
    // this will update the menu when it's clicked
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        
        if menuItem.title == "Lock Screen".translate {
            updateUserInfo()
        }
        
        // disable the menus that don't work if you're not logged in
        
        if self.userInformation.connected == false {
            
            self.NoMADMenuLogIn.isHidden = false
            self.NoMADMenuLogIn.isEnabled = false
            self.NoMADMenuLogIn.title = "SignIn".translate
            if (self.NoMADMenuLogOut != nil) {
                self.NoMADMenuLogOut.isEnabled = false
            }
            if (self.NoMADMenuChangePassword != nil) {
                self.NoMADMenuChangePassword.isEnabled = false
            }
            if (self.NoMADMenuGetCertificate != nil)  {
                self.NoMADMenuGetCertificate.isEnabled = false
            }
            
                self.PKINITMenuItem.isEnabled = false

            
            // twiddles what needs to be twiddled for connected but not logged in
            
        } else if self.userInformation.myLDAPServers.tickets.state == false {
            
            self.NoMADMenuLogIn.isEnabled = true
            self.NoMADMenuLogIn.title = "SignIn".translate
            self.NoMADMenuLogIn.action = #selector(self.NoMADMenuClickLogIn)
            self.NoMADMenuLogIn.isHidden = false
            if (self.NoMADMenuLogOut != nil) {
                self.NoMADMenuLogOut.isEnabled = false
            }
            if (self.NoMADMenuChangePassword != nil) {
                self.NoMADMenuChangePassword.isEnabled = false
            }
            if (self.NoMADMenuGetCertificate != nil)  {
                self.NoMADMenuGetCertificate.isEnabled = false
            }
                self.PKINITMenuItem.isEnabled = true

        }
        else {
            if defaults.bool(forKey: Preferences.hideRenew) {
                self.NoMADMenuLogIn.isEnabled = false
            } else {
                self.NoMADMenuLogIn.isEnabled = true
            }
            
            self.NoMADMenuLogIn.title = defaults.string(forKey: Preferences.menuRenewTickets) ?? "NoMADMenuController-RenewTickets".translate
            self.NoMADMenuLogIn.action = #selector(self.renewTickets)
            if (self.NoMADMenuLogOut != nil) {
                self.NoMADMenuLogOut.isEnabled = true
            }
            if (self.NoMADMenuChangePassword != nil) {
                self.NoMADMenuChangePassword.isEnabled = true
            }
            if (self.NoMADMenuGetCertificate != nil)  {
                
                // Getting list of Certificates
                let keychainUtilInstance = KeychainUtil()
                let certList = keychainUtilInstance.findAllUserCerts(self.userInformation.UPN, defaultNamingContext: self.userInformation.myLDAPServers.defaultNamingContext )
                
                if certList != nil {
                    
                    // Determining whether to hide the certificate button or not
                    if let certMaximum = defaults.object(forKey: Preferences.hideCertificateNumber) as? Int{
                        if ((certList?.count ?? 0) >= certMaximum) {
                            myLogger.logit(.debug, message: "Hiding the certificate menu")
                            self.NoMADMenuGetCertificate.isEnabled = false
                        }
                    } else {
                        self.NoMADMenuGetCertificate.isEnabled = true
                    }
                }
            }
        }
        
        if defaults.bool(forKey: Preferences.hidePrefs) {
            //self.NoMADMenuPreferences.isEnabled = false
            NoMADMenuPreferences.isHidden = true
            NoMADMenuPreferences.isEnabled = false
            NoMADMenuSpewLogs.isHidden = true
            
            myLogger.logit(.notice, message:NSLocalizedString("NoMADMenuController-PreferencesDisabled", comment: "Log; Text; Preferences Disabled"))
        }
        
        return true
    }
    
    // display a user notifcation
    @objc func showNotification(_ title: String, text: String, date: Date, action: String) -> Void {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = text
        //notification.deliveryDate = date
        if action != "" {
            notification.hasActionButton = true
            notification.actionButtonTitle = action.translate
        }
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    // Notification delegates
    
    // NSUserNotificationCenterDelegate implementation
    func userNotificationCenter(_ center: NSUserNotificationCenter, didDeliver notification: NSUserNotification) {
        //implementation
    }
    
    func userNotificationCenter(_ center: NSUserNotificationCenter, didActivate notification: NSUserNotification) {
        if notification.actionButtonTitle == "NoMADMenuController-ChangePassword".translate {
            myLogger.logit(.base, message: "Initiating user password change.")
            if defaults.string(forKey: Preferences.changePasswordType) != "Kerberos"  {
                PasswordChange().passwordChange()
            } else {
                passwordChangeWindow.window!.forceToFrontAndFocus(nil)
            }
            
        } else if notification.actionButtonTitle == "SignIn".translate {
            myLogger.logit(.base, message: "Initiating unannounced password change recovery.")
            // kill the tickets and show the loginwindow
           let _ =  cliTask("/usr/bin/kdestroy")
            
            // fire off the SignOutCommand script if there is one
            
            if let command = defaults.string(forKey: Preferences.signOutCommand) {
                let myResult = cliTask(command)
                myLogger.logit(LogLevel.base, message: myResult)
            }
            
            DispatchQueue.main.async {

            loginWindow.window!.forceToFrontAndFocus(nil)
            }
            
        } else if notification.actionButtonTitle == "Ignore" {
            return
        }
    }
    
    // pulls user's entire LDAP record when asked
    @objc func logEntireUserRecord() {
        let myResult = userInformation.myLDAPServers.returnFullRecord("sAMAccountName=" + defaults.string(forKey: Preferences.lastUser)!)
        myLogger.logit(.base, message:myResult)
    }
    
    // everything to do on a network change
    @objc func doTheNeedfull() {
        
        if ( self.userInformation.myLDAPServers.getDomain() == "not set" ) {
            //self.userInformation.myLDAPServers.tickets.getDetails()
            self.userInformation.myLDAPServers.currentDomain = defaults.string(forKey: Preferences.aDDomain)!
        }
        
        self.updateUserInfo()
    }
    
    // simple function to renew tickets
    @objc func renewTickets(){
       let _ =  cliTask("/usr/bin/kinit -R")
        userInformation.myLDAPServers.tickets.klist()
        if defaults.bool(forKey: Preferences.verbose) == true {
            myLogger.logit(.base, message:"Renewing tickets.")
        }
    }
    
    @objc func animateMenuItem() {
        if statusItem.image == iconOnOn {
            statusItem.image = iconOffOff
        } else {
            statusItem.image = iconOnOn
        }
    }
    
    @objc func testSite(caURL: String, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) {
        
        let request = NSMutableURLRequest(url: URL(string: caURL)!)
        
        request.httpMethod = "GET"
        
        let session = URLSession.shared
        session.dataTask(with: request as URLRequest, completionHandler: completionHandler).resume()
    }
    
    // function to see if we should autologin and then proceed accordingly
    @objc func autoLogin() {
        // only autologin if 1) we're set to use the keychain, 2) we have don't already have a Kerb ticket and 3) we can contact the LDAP servers
        
        if defaults.bool(forKey: Preferences.useKeychain) && (defaults.string(forKey: Preferences.lastUser) != "" ) && !userInformation.myLDAPServers.tickets.state && userInformation.myLDAPServers.currentState {
            
            myLogger.logit(.info, message: "Attempting to auto-login")
            
            // check if there's a last user
            var myPass = ""
            var myErr: String?
            let userPrinc = defaults.string(forKey: Preferences.lastUser)! + "@" + defaults.string(forKey: Preferences.kerberosRealm)!
            
            do {
                myPass = try myKeychainutil.findPassword(userPrinc)
            } catch {
                myLogger.logit(.base, message: "Unable to find password in keychain for auto-login.")
                updateUserInfo()
                if defaults.bool(forKey: Preferences.useKeychainPrompt) {
                    DispatchQueue.main.async {
                    loginWindow.window!.forceToFrontAndFocus(nil)
                    }
                }
                return
            }
            
            let myKerbUtil = KerbUtil()
            myErr = myKerbUtil.getKerbCredentials(myPass, userPrinc)
            
            while ( !myKerbUtil.finished ) {
                RunLoop.current.run(mode: RunLoopMode.defaultRunLoopMode, before: Date.distantFuture)
            }
            
            if myErr == nil {
                myLogger.logit(.base, message:"Automatically logged in.")
                
                let _ = cliTask("/usr/bin/kswitch -p " +  userPrinc)
                
                // update the UI
                
                updateUserInfo()
                
                // fire off the SignInCommand script if there is one
                if defaults.string(forKey: Preferences.signInCommand) != "" {
                    let myResult = cliTask(defaults.string(forKey: Preferences.signInCommand)!)
                    myLogger.logit(.base, message: myResult)
                }
                return
            } else if (myErr?.contains("Cannot contact any KDC for requested realm"))! {
                myLogger.logit(.base, message:"Autologin can't find KDCs.")
                return
            } else if (myErr?.contains("kGSSMinorErrorCode=-1765328378"))! {
                myLogger.logit(.base, message:"Autologin failed because of unkown user.")
                return
            } else if (myErr?.contains("Preauthentication failed"))! {
                myLogger.logit(.base, message:"Autologin password error.")
                // password failed, let's delete it so as to not fail again
                var myKeychainItem: SecKeychainItem?
                var myErr: OSStatus
                let serviceName = "NoMAD"
                var passLength: UInt32 = 0
                var passPtr: UnsafeMutableRawPointer? = nil
                let name = defaults.string(forKey: Preferences.lastUser)! + "@" + defaults.string(forKey: Preferences.kerberosRealm)!
                
                myErr = SecKeychainFindGenericPassword(nil,
                                                       UInt32(serviceName.count),
                                                       serviceName,
                                                       UInt32(name.count),
                                                       name,
                                                       &passLength,
                                                       &passPtr, &myKeychainItem)
                if (myErr == 0) {
                    SecKeychainItemDelete(myKeychainItem!)
                } else {
                    myLogger.logit(.base, message:"Error deleting Keychain entry.")
                }
                // now show the window
                DispatchQueue.main.async {
                loginWindow.window!.forceToFrontAndFocus(nil)
                }
            } else  {
                myLogger.logit(.base, message:"Error attempting to automatically log in.")
                return
            }
        } else {
            myLogger.logit(.base, message: "Auto-login not attempted.")
        }
        
        // if keychain prompt is set ensure we have a keychain item
        
        // only do this if 1) we have the default set 2) we are on the domain 3) we do not have a password in the keychain
        
        if defaults.bool(forKey: Preferences.useKeychainPrompt) && (defaults.string(forKey: Preferences.lastUser) != "") && userInformation.myLDAPServers.currentState  {
            do {
                myLogger.logit(.debug, message: "Checking if the user has a password in the keychain.")
                
                // we don't need to know the password, just that one is there
                
                let userPrinc = defaults.string(forKey: Preferences.lastUser)! + "@" + defaults.string(forKey: Preferences.kerberosRealm)!
                
               let _ = try myKeychainutil.findPassword(userPrinc)
                
            } catch {
                // no password - prompt the user to sign in
                DispatchQueue.main.async {
                loginWindow.window!.forceToFrontAndFocus(nil)
                }
            }
        }
    }
    
    // Share Mount functions
    
    @objc func mountShareFromMenu(share: URL) {
        
    }
    
    func openShareFromMenu(_ sender: AnyObject) {
                
        for share in myShareMounter.all_shares {
            if share.name == sender.title {
                if share.mountStatus != .mounted && share.mountStatus != .mounting {
                    myLogger.logit(.debug, message: "Mounting share: " + String(describing: share.url))
                    myShareMounter.asyncMountShare(share.url, options: share.options, open: true)
                    //cliTask("open " + share.url.absoluteString.addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlPathAllowed)!)
                } else if share.mountStatus == .mounted {
                    print(share.localMountPoints ?? "")
                    // open up the local shares
                    NSWorkspace.shared.open(URL(fileURLWithPath: share.localMountPoints!, isDirectory: true))
                }
            }
        }
    }
    
    // change the menu item if it's dark
    
    @objc func interfaceModeChanged() {
        if UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?["AppleInterfaceStyle"] == nil {
            if !defaults.bool(forKey: Preferences.caribouTime) {
                iconOnOn = myIconOn
                iconOnOff = NSImage(named: NSImage.Name(rawValue: "NoMAD-statusicon-on-off"))!
                iconOffOff = myIconOff
            } else {
                iconOnOn = NSImage(named: NSImage.Name(rawValue: "NoMAD-Caribou-on"))!
                iconOffOff = NSImage(named: NSImage.Name(rawValue: "NoMAD-Caribou-off"))!
            }
        } else {
            if !defaults.bool(forKey: Preferences.caribouTime) {
                iconOnOn = myIconOnDark
                //iconOnOff = NSImage(named: "NoMAD-statusicon-on-off")
                iconOffOff = myIconOffDark
            } else {
                iconOnOn = NSImage(named: NSImage.Name(rawValue: "NoMAD-Caribou-dark-on"))!
                iconOffOff = NSImage(named: NSImage.Name(rawValue: "NoMAD-Caribou-dark-off"))!
            }
        }
        if self.userInformation.status == "Connected" {
            self.statusItem.image = self.iconOnOff
        } else if self.userInformation.status == "Logged In" && self.userInformation.myLDAPServers.tickets.state {
            self.statusItem.image = self.iconOnOn
        } else {
            self.statusItem.image = self.iconOffOff
        }
    }
    
    
    @objc func handleAppleEvent(_ event: NSAppleEventDescriptor, withReplyEvent: NSAppleEventDescriptor) {
        let fullCommand = URL(string: (event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue)!)
        
        let command = fullCommand?.host
        
        switch command! {
            
            // TODO: Lots of error handling and such
            
        case "getcertificate":
            getCert(false)
        case "gethelp" :
            GetHelp().getHelp()
        case "getsoftware" :
            NoMADMenuClickGetSoftware(NoMADMenuGetSoftware)
        case "open": break
        case "passwordchange":
            if self.userInformation.connected && self.userInformation.myLDAPServers.tickets.state {
                passwordChangeWindow.window!.forceToFrontAndFocus(nil)
            } else {
                myLogger.logit(.debug, message: "User not currently signed in, unable to show change password window.")
            }
        case "prefs":
            preferencesWindow.window!.forceToFrontAndFocus(nil)
        case "signin":
            if self.userInformation.connected && !self.userInformation.myLDAPServers.tickets.state {
                if let user = fullCommand?.user {
                    let password = fullCommand?.password
                    let userPrinc = user + "@" + defaults.string(forKey: Preferences.kerberosRealm)!
                    let myKerbUtil = KerbUtil()
                    let myErr = myKerbUtil.getKerbCredentials(password, userPrinc)
                    print("\(String(describing: myErr))")
                    if myErr == nil {
                        let keychainUtil = KeychainUtil()
                        let status = keychainUtil.updatePassword(userPrinc, pass: password!)
                        print(status)
                    }
                    doTheNeedfull()
                } else {
                    DispatchQueue.main.async {
                    loginWindow.window!.forceToFrontAndFocus(nil)
                    }
                }
            }
        case "update":
            doTheNeedfull()
        case "cleancerts":
            KeychainUtil().cleanCerts()
        case "action":
            
            if nActionMenu.actions.count < 1 {
                break
            }
            
            let actionToRun = fullCommand?.path.replacingOccurrences(of: "/", with: "").removingPercentEncoding ?? "none"
            
            for i in 0...(nActionMenu.actions.count - 1 ) {
                if nActionMenu.actions[i].actionName == actionToRun {
                    _ = nActionMenu.actions[i].runActionCLI()
                }
            }
            
        case "actionsilent":
            
            if nActionMenu.actions.count < 1 {
                break
            }
            
            let actionToRun = fullCommand?.path.replacingOccurrences(of: "/", with: "").removingPercentEncoding ?? "none"
            
            for i in 0...(nActionMenu.actions.count - 1 ) {
                if nActionMenu.actions[i].actionName == actionToRun {
                    _ = nActionMenu.actions[i].runActionCLISilent()
                }
            }
            
        default:
            break
        }
    }
    
    // function to start the menu throbbing
    @objc func startMenuAnimationTimer() {
        if !menuAnimated {
            menuAnimationTimer = Timer(timeInterval: 0.5, target: self, selector: #selector(animateMenuItem), userInfo: nil, repeats: true)
            //statusItem.menu = NSMenu()
            RunLoop.main.add(menuAnimationTimer, forMode: RunLoopMode.defaultRunLoopMode)
            menuAnimationTimer.fire()
            menuAnimated = true
        }
    }
    
    @objc func stopMenuAnimationTimer() {
        if menuAnimated{
            menuAnimationTimer.invalidate()
            //menuAnimationTimer.invalidate()
            menuAnimated = false
        }
        
        // now set it rights
        if self.userInformation.status == "Connected" {
            self.statusItem.image = self.iconOnOff
        } else if self.userInformation.status == "Logged In" && self.userInformation.myLDAPServers.tickets.state {
            self.statusItem.image = self.iconOnOn
        } else {
            self.statusItem.image = self.iconOffOff
        }
    }
    
    // function to ensure that the basic kerb prefs are there
    
    @objc func configureKerbPefs() {
        let homePath = NSHomeDirectory() + "/Library/Preferences/com.apple.Kerberos.plist"
        
        let plistRaw = try? Data.init(contentsOf: URL.init(fileURLWithPath: homePath))
        
        if plistRaw == nil {
            return
        }
        
        guard var plistDict = try? PropertyListSerialization.propertyList(from: plistRaw!, options: .mutableContainersAndLeaves, format: nil) as? [ String : Any ] else { return }
        
        // check for a default realm
        
        if ( plistDict!["libdefaults"] ?? nil ) == nil {
            
            myLogger.logit(.base, message: "Writing out default Kerberos realm.")
            
            // no realm so build one
            
            let defaultBlock = [
                "default_realm" : defaults.string(forKey: Preferences.kerberosRealm) ?? "none"
            ]
            plistDict!["libdefaults"] = defaultBlock
            
            // no make it back into a plist
            
            guard let plistData = try? PropertyListSerialization.data(fromPropertyList: plistDict ?? [String : Any ](), format: .binary, options: PropertyListSerialization.WriteOptions.init(0)) else { return }
            
            // write it out
            
            try? plistData.write(to: URL.init(fileURLWithPath: homePath))
            
        } else {
            myLogger.logit(.base, message: "Kerberos configuration file exists")
        }
    }
    
    // function to configure Chrome
    
    @objc func configureChrome() {
        
        // create new instance of defaults for com.google.Chrome
        
        let chromeDefaults = UserDefaults.init(suiteName: "com.google.Chrome")
        let chromeDomain = defaults.string(forKey: Preferences.configureChromeDomain) ?? defaults.string(forKey: Preferences.aDDomain)!
        
        let chromeDomainParts = chromeDomain.components(separatedBy: ",")
        
        var change = false
        
        // find the keys and add the domain
        
        let chromeAuthServer = chromeDefaults?.string(forKey: "AuthServerWhitelist")
        var chromeAuthServerArray = chromeAuthServer?.components(separatedBy: ",")
        
        let chromeAuthNegotiate = chromeDefaults?.string(forKey: "AuthNegotiateDelegateWhitelist")
        var chromeAuthNegotiateArray = chromeAuthNegotiate?.components(separatedBy: ",")
        
        for domain in chromeDomainParts {
            
            // add the wildcard
            
            let currentDomain = "*" + domain
            
            if chromeAuthServerArray != nil {
                if !((chromeAuthServerArray?.contains(currentDomain))!) {
                    chromeAuthServerArray?.append(currentDomain)
                    change = true
                }
            } else {
                chromeAuthServerArray = [currentDomain]
                change = true
            }
            
            if chromeAuthNegotiateArray != nil {
                if !((chromeAuthNegotiateArray?.contains(currentDomain))!) {
                    chromeAuthNegotiateArray?.append(currentDomain)
                    change = true
                }
            } else {
                chromeAuthNegotiateArray = [currentDomain]
                change = true
            }
        }
        
        // write it back
        
        if change {
            myLogger.logit(.base, message: "Adding keys to Chrome preferences.")
            
            chromeDefaults?.set(chromeAuthServerArray?.joined(separator: ","), forKey: "AuthServerWhitelist")
            chromeDefaults?.set(chromeAuthNegotiateArray?.joined(separator: ","), forKey: "AuthNegotiateDelegateWhitelist")
        }
        
        //cliTask("defaults write com.google.Chrome AuthServerWhitelist \"*." + defaults.string(forKey: Preferences.aDDomain)! + "\"")
        //cliTask("defaults write com.google.Chrome AuthNegotiateDelegateWhitelist \"*." + defaults.string(forKey: Preferences.aDDomain)! + "\"")
    }
    
    // update the user info and build the actual menu
    
    @objc func updateUserInfo() {
        
        myLogger.logit(.base, message:"Updating User Info")
        updateRunning = true
        
        //startMenuAnimationTimer()
        
        // make sure the domain we're using is the domain we should be using
        
        if ( userInformation.myLDAPServers.getDomain() != defaults.string(forKey: Preferences.aDDomain)!) {
            userInformation.myLDAPServers.setDomain(defaults.string(forKey: Preferences.aDDomain)!)
        }
        
        // check for network reachability
        // we do this in the background and then time out if it doesn't complete
        
        var reachCheck = false
        let reachCheckDate = Date()
        
        reachCheckQueue.async(execute: {
            
            let host = defaults.string(forKey: Preferences.aDDomain)
            let myReach = SCNetworkReachabilityCreateWithName(nil, host!)
            var flag = SCNetworkReachabilityFlags.reachable
            
            myLogger.logit(.debug, message: "Starting reachability check.")
            
            if !SCNetworkReachabilityGetFlags(myReach!, &flag) {
                myLogger.logit(.base, message: "Can't determine network reachability.")
                self.lastStatusCheck = Date()
            }
            
            if (flag.rawValue != UInt32(kSCNetworkFlagsReachable)) {
                // network isn't reachable
                myLogger.logit(.base, message: "Network is not reachable, delaying lookups.")
                //self.lastStatusCheck = Date()
            }
            reachCheck = true
        })
        
        while !reachCheck && (abs(reachCheckDate.timeIntervalSinceNow) < 5) {
            RunLoop.main.run(mode: RunLoopMode.defaultRunLoopMode, before: Date.distantFuture)
            myLogger.logit(.debug, message: "Waiting for reachability check to return.")
            myLogger.logit(.debug, message: "Counting... " + String(abs(reachCheckDate.timeIntervalSinceNow)))
        }
        
        if !reachCheck {
            myLogger.logit(.base, message: "Reachability check timed out.")
            self.lastStatusCheck = Date()
        }
        
        if abs(lastStatusCheck.timeIntervalSinceNow) > 3 || firstRun {
            
            // through the magic of code blocks we'll update in the background
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            
            myWorkQueue.async(execute: {
                
                // don't do this if we don't have a network
                
                self.userInformation.getUserInfo()
                
                DispatchQueue.main.sync(execute: { () -> Void in
                    
                    // check shares
                    
                    shareMounterMenu.updateShares(connected: self.userInformation.connected)
                    
                    // build the menu
                    
                    self.statusItem.menu = self.NoMADMenu
                    
                    // set the menu icon
                    if self.userInformation.status == "Connected" {
                        self.statusItem.image = self.iconOnOff
                        self.statusItem.alternateImage = self.iconAltOnOff
                        
                        // we do this twice b/c doing it only once seems to make it less than full width
                        self.statusItem.title = self.userInformation.status.translate
                        self.statusItem.title = self.userInformation.status.translate
                        
                        // if we're not logged in we disable some options
                        
                        self.statusItem.toolTip = dateFormatter.string(from: self.userInformation.userPasswordExpireDate as Date)
                        self.NoMADMenuTicketLife.title = "NoMADMenuController-NotLoggedIn".translate + " NoMAD Version: " + String(describing: Bundle.main.infoDictionary!["CFBundleShortVersionString"]!)
                        
                    } else if self.userInformation.status == "Logged In" && self.userInformation.myLDAPServers.tickets.state || defaults.bool(forKey: Preferences.persistExpiration) {
                        self.statusItem.image = self.iconOnOn
                        self.statusItem.alternateImage = self.iconAltOnOn
                        
                        // if we're logged in we enable some options
                        
                        // self.NoMADMenuLogOut.enabled = true
                        // self.NoMADMenuChangePassword.enabled = true
                        
                        if self.userInformation.passwordAging {
                            
                            self.statusItem.toolTip = dateFormatter.string(from: self.userInformation.userPasswordExpireDate as Date)
                            
                            self.NoMADMenuTicketLife.title = dateFormatter.string(from: self.userInformation.myLDAPServers.tickets.defaultExpires ?? Date.distantPast) + " " + self.userInformation.myLDAPServers.currentServer + " NoMAD Version: " + String(describing: Bundle.main.infoDictionary!["CFBundleShortVersionString"]!)
                            
                            let daysToGo = Int(abs(self.userInformation.userPasswordExpireDate.timeIntervalSinceNow)/86400)
                            
                            if defaults.string(forKey: Preferences.passwordExpireCustomAlert) != nil {
                                
                                let len = defaults.string(forKey: Preferences.passwordExpireCustomAlert)?.count
                                
                                var myMutableString = NSMutableAttributedString(string: defaults.string(forKey: Preferences.passwordExpireCustomAlert) ?? "")
                                
                                if defaults.string(forKey: Preferences.passwordExpireCustomAlert) == "<<days>>" {
                                    myMutableString = NSMutableAttributedString(string: String(daysToGo) + "d".translate)
                                }
                                
                                if Int(daysToGo) < defaults.integer(forKey: Preferences.passwordExpireCustomAlertTime) {
                                    
                                    myMutableString.addAttribute(NSAttributedStringKey.foregroundColor, value: NSColor.red, range: NSRange(location: 0, length: len!))
                                    
                                    self.statusItem.attributedTitle = myMutableString
                                    self.statusItem.attributedTitle = myMutableString
                                    
                                } else if Int(daysToGo) < defaults.integer(forKey: Preferences.passwordExpireCustomWarnTime) {
                                    
                                    myMutableString.addAttribute(NSAttributedStringKey.foregroundColor, value: NSColor.yellow, range: NSRange(location: 0, length: len!))
                                    
                                    self.statusItem.attributedTitle = myMutableString
                                    self.statusItem.attributedTitle = myMutableString
                                    
                                    
                                } else {
                                    // reset to nothing
                                    let myMutableString = NSMutableAttributedString(string: "")
                                    self.statusItem.attributedTitle = myMutableString
                                    self.statusItem.attributedTitle = myMutableString
                                }
                                self.NoMADMenuPasswordExpires.title = String(format: "NoMADMenuController-PasswordExpiresInDays".translate, String(daysToGo))
                                
                            } else {
                                
                                // we do this twice b/c doing it only once seems to make it less than full width
                                if Int(daysToGo) > 4 {
                                    self.statusItem.title = (String(daysToGo) + "d".translate )
                                    self.statusItem.title = (String(daysToGo) + "d".translate )
                                    self.NoMADMenuPasswordExpires.title = String(format: "NoMADMenuController-PasswordExpiresInDays".translate, String(daysToGo))
                                } else {
                                    
                                    let myMutableString = NSMutableAttributedString(string: String(daysToGo) + "d".translate)
                                    myMutableString.addAttribute(NSAttributedStringKey.foregroundColor, value: NSColor.red, range: NSRange(location: 0, length: 2))
                                    self.statusItem.attributedTitle = myMutableString
                                    self.statusItem.attributedTitle = myMutableString
                                    self.NoMADMenuPasswordExpires.title = String(format: "NoMADMenuController-PasswordExpiresInDays".translate, String(daysToGo))
                                }
                            }
                        } else {
                            
                            // we do this twice b/c doing it only once seems to make it less than full width
                            self.statusItem.title = ""
                            self.statusItem.title = ""
                            self.NoMADMenuTicketLife.title = dateFormatter.string(from: self.userInformation.myLDAPServers.tickets.defaultExpires ?? Date.distantPast) + " " + self.userInformation.myLDAPServers.currentServer + " NoMAD Version: " + String(describing: Bundle.main.infoDictionary!["CFBundleShortVersionString"]!)
                            self.statusItem.toolTip = defaults.string(forKey: Preferences.hideExpirationMessage) ?? "PasswordDoesNotExpire".translate
                            self.NoMADMenuPasswordExpires.title = defaults.string(forKey: Preferences.hideExpirationMessage) ?? "PasswordDoesNotExpire".translate
                        }
                    } else {
                        self.statusItem.image = self.iconOffOff
                        self.statusItem.alternateImage = self.iconAltOffOff
                        
                        self.NoMADMenuTicketLife.title = "NoMAD Version: " + String(describing: Bundle.main.infoDictionary!["CFBundleShortVersionString"]!)
                        
                        // if online we don't set a status message
                        
                        if self.userInformation.connected {
                            // we do this twice b/c doing it only once seems to make it less than full width
                            self.statusItem.title = self.userInformation.status.translate
                            self.statusItem.title = self.userInformation.status.translate
                        } else {
                            
                            // use the custom message if it exists
                            
                            // we do this twice b/c doing it only once seems to make it less than full width
                            self.statusItem.title = defaults.string(forKey: Preferences.messageNotConnected) ?? self.userInformation.status.translate
                            self.statusItem.title = defaults.string(forKey: Preferences.messageNotConnected) ?? self.userInformation.status.translate
                        }
                    }
                    
                    if ( self.userInformation.userPrincipalShort != "No User" ) {
                        if self.userInformation.userPrincipalShort != "" {
                            self.NoMADMenuUserName.title = self.userInformation.userPrincipalShort
                        } else {
                            self.NoMADMenuUserName.title = defaults.string(forKey: Preferences.menuUserName) ?? "NoMADMenuController-NotSignedIn".translate
                        }
                    } else {
                        self.NoMADMenuUserName.title = defaults.string(forKey: Preferences.lastUser) ?? "NoMADMenuController-NoUser".translate
                        self.NoMADMenuPasswordExpires.title = ""
                    }

                    // Commented out dead code
//                    let futureDate = Date()
//                    futureDate.addingTimeInterval(300)

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
                            self.NoMADMenuHome.title = defaults.string(forKey: Preferences.menuHomeDirectory) ?? "HomeSharepoint".translate
                            self.NoMADMenuHome.action = #selector(self.homeClicked)
                            self.NoMADMenuHome.target = self
                            self.NoMADMenuHome.isEnabled = true
                            // should key this off of the position of the Preferences menu
                            let prefIndex = self.NoMADMenu.index(of: self.NoMADMenuPreferences)
                            self.NoMADMenu.insertItem(self.NoMADMenuHome, at: (prefIndex - 1 ))
                        } else if self.userInformation.userHome != "" && self.NoMADMenu.items.contains(self.NoMADMenuHome) {
                            self.NoMADMenuHome.title = defaults.string(forKey: Preferences.menuHomeDirectory) ?? "HomeSharepoint".translate
                            self.NoMADMenuHome.action = #selector(self.homeClicked)
                            self.NoMADMenuHome.target = self
                            self.NoMADMenuHome.isEnabled = true
                        } else if self.NoMADMenu.items.contains(self.NoMADMenuHome) {
                            self.NoMADMenu.removeItem(self.NoMADMenuHome)
                        }
                    }
                    
                    // ACTIONS
                    
                    // update the actions first
                    
                    nActionMenu.updateActions(self.userInformation.connected)
                    
                    // pivot on if the menu exists or not
                    
                    if !self.NoMADMenu.items.contains(self.myActionsMenu) {
                        
                        nActionMenu.createMenu()
                        
                        if nActionMenu.actionMenu.items.count > 0 {
                            // we have a menu add it to the main menu
                            
                            self.myActionsMenu.title = defaults.string(forKey: Preferences.menuActions) ?? "Actions"
                            self.myActionsMenu.submenu = nActionMenu.actionMenu
                            
                            // check the icon
                            
                            if nActionMenu.menuIconEnabled && nActionMenu.menuIcon != nil {
                                self.myActionsMenu.image = nActionMenu.menuIcon
                            } else {
                                self.myActionsMenu.image = nil
                            }
                            
                            // check the menu title
                            
                            if nActionMenu.menuTextEnabled && nActionMenu.menuText != nil {
                                self.myActionsMenu.title = nActionMenu.menuText!
                            } else {
                                self.myActionsMenu.title = defaults.string(forKey: Preferences.menuActions) ?? "Actions"
                            }
                            
                            let lockIndex = self.NoMADMenu.index(of: self.NoMADMenuLockScreen)
                            self.NoMADMenu.insertItem(self.myActionsMenu, at: (lockIndex + 1 ))

                        }
                        
                    } else {
                        nActionMenu.updateMenu()
                        
                        // check the menu title
                        
                        if nActionMenu.menuTextEnabled && nActionMenu.menuText != nil {
                            self.myActionsMenu.title = nActionMenu.menuText!
                        } else {
                            self.myActionsMenu.title = defaults.string(forKey: Preferences.menuActions) ?? "Actions"
                        }
                        
                        if nActionMenu.menuIconEnabled && nActionMenu.menuIcon != nil {
                            self.myActionsMenu.image = nActionMenu.menuIcon
                        } else {
                            self.myActionsMenu.image = nil
                        }
                    }
                    
                    
                    
                    if self.userInformation.status == "Logged In" {
                        
                        self.myShareMenuItem.title = defaults.string(forKey: Preferences.menuFileServers) ?? "FileServers".translate
                        self.myShareMenuItem.submenu = shareMounterMenu.buildMenu(connected: self.userInformation.connected)
                        
                        if shareMounterMenu.sharesAvilable() {
                            
                            // light it up
                            
                            if !self.NoMADMenu.items.contains(self.myShareMenuItem) {
                                let lockIndex = self.NoMADMenu.index(of: self.NoMADMenuLockScreen)
                                self.NoMADMenu.insertItem(self.myShareMenuItem, at: (lockIndex + 1 ))
                            }
                        } else {
                            // remove the menu if it exists
                            
                            if self.NoMADMenu.items.contains(self.myShareMenuItem) {
                                self.NoMADMenu.removeItem(self.myShareMenuItem)
                            }
                        }
                    }  else {
                        // remove the menu if it exists
                        
                        if self.NoMADMenu.items.contains(self.myShareMenuItem) {
                            self.NoMADMenu.removeItem(self.myShareMenuItem)
                        }
                    }
                    
                })
                
                // check if we need to renew the ticket
                
                if defaults.bool(forKey: Preferences.renewTickets) && self.userInformation.status == "Logged In" && ( abs(self.userInformation.myLDAPServers.tickets.defaultExpires?.timeIntervalSinceNow ?? Date.distantPast.timeIntervalSinceNow) <= Double(defaults.integer(forKey: Preferences.secondsToRenew))) {
                    self.renewTickets()
                }
                
                // reset the counter if the password change is over the default
                
                if ( abs(self.userInformation.userPasswordExpireDate.timeIntervalSinceNow) < Double(defaults.integer(forKey: Preferences.passwordExpireAlertTime)) && self.userInformation.status == "Logged In" ) && self.userInformation.passwordAging {
                    
                    if ( abs(self.userInformation.userPasswordExpireDate.timeIntervalSinceNow) < Double(defaults.integer(forKey: Preferences.lastPasswordWarning)) ) {
                        if ( abs(self.userInformation.userPasswordExpireDate.timeIntervalSinceNow) > Double(345600) ) {
                            // expire is between default and four days so notify once a day
                            self.showNotification("PasswordAboutToExpire".translate, text: "PasswordExpiresOn".translate + dateFormatter.string(from: self.userInformation.userPasswordExpireDate as Date), date: Date(), action: "NoMADMenuController-ChangePassword")
                            defaults.set((abs(self.userInformation.userPasswordExpireDate.timeIntervalSinceNow) - 86400 ), forKey: Preferences.lastPasswordWarning)
                        } else if ( abs(self.userInformation.userPasswordExpireDate.timeIntervalSinceNow) > Double(86400) ) {
                            // expire is between 4 days and 1 day so notifiy every 12 hours
                            self.showNotification("PasswordAboutToExpire".translate, text: "PasswordExpiresOn".translate + dateFormatter.string(from: self.userInformation.userPasswordExpireDate as Date), date: Date(), action: "NoMADMenuController-ChangePassword")
                            defaults.set( (abs(self.userInformation.userPasswordExpireDate.timeIntervalSinceNow) - 23200 ), forKey: Preferences.lastPasswordWarning)
                        } else {
                            // expire is less than 1 day so notifiy every hour
                            self.showNotification("PasswordAboutToExpire".translate, text: "PasswordExpiresOn".translate + dateFormatter.string(from: self.userInformation.userPasswordExpireDate as Date), date: Date(), action: "NoMADMenuController-ChangePassword")
                            defaults.set((abs(self.userInformation.userPasswordExpireDate.timeIntervalSinceNow) - 3600 ), forKey: Preferences.lastPasswordWarning)
                        }
                    }
                } else {
                    defaults.set(Double(defaults.integer(forKey: Preferences.passwordExpireAlertTime) ), forKey: Preferences.lastPasswordWarning)
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
                    self.NoMADMenuGetCertificate.title = defaults.string(forKey: Preferences.menuGetCertificate) ?? "Get Certificate"
                }
                
                // login if we need to
                if reachCheck { self.autoLogin() }
                
                // if we're set to show the sign in window on launch, show it, if we don't already have tickets
                
                if defaults.bool(forKey: Preferences.signInWindowOnLaunch) && self.userInformation.connected && !self.userInformation.myLDAPServers.tickets.state && !self.signInOffered {
                    
                    // check to ensure we're not a member of an exclusion group
                    
                    if !((defaults.array(forKey: Preferences.signInWindowOnLaunchExclusions)?.contains(where: { ($0 as! String)  == NSUserName() } )) ?? false ) {
                        
                        // move this back to the foreground
                        DispatchQueue.main.async {
                            self.NoMADMenuClickLogIn(NSMenuItem())
                            self.signInOffered = true
                        }
                    }
                }
                
                
                self.updateRunning = false
            })
            
            // check for locked keychains
            
            if myKeychainutil.checkLockedKeychain() && defaults.bool(forKey: Preferences.lockedKeychainCheck) {
                // notify on the keychain
                myLogger.logit(.base, message: "Keychain is locked, showing notification.")
                keychainMinder.window?.forceToFrontAndFocus(nil)
            }
            
            // mark the time and clear the update scheduled flag
            
            lastStatusCheck = Date()
            updateScheduled = false
            
            if let expireDate = defaults.object(forKey: Preferences.lastCertificateExpiration) as? Date {
                if expireDate != Date.distantPast {
                    NoMADMenuGetCertificateDate.title = dateFormatter.string(from: expireDate)
                } else {
                    NoMADMenuGetCertificateDate.title = "No Certs"
                }
                
                if defaults.integer(forKey: Preferences.autoRenewCert) != 0 && (expireDate.timeIntervalSinceNow < Double( 24 * 60 * 60 * defaults.integer(forKey: Preferences.autoRenewCert))) {
                    // cert has expired, or will expire, and we should renew
                    myLogger.logit(.base, message: "Attempting to get a new certificate automatically.")
                    
                    self.getCert(false)
                    
                    // set the date to now so we don't get a second cert
                    defaults.set(Date(), forKey: Preferences.lastCertificateExpiration)
                    
                }
                
            } else {
                myLogger.logit(.debug, message: "No Certificate expiration saved.")
                
                //Checking if the cert should be automatically retrieved
                
                if defaults.bool(forKey: Preferences.getCertAutomatically) {
                    myLogger.logit(.base, message: "Attempting to get certificate automatically.")
                    self.getCert(false)
                    
                    // set the date to now so we don't get a second cert
                    defaults.set(Date(), forKey: Preferences.lastCertificateExpiration)
                }
            }
        } else {
            myLogger.logit(.info, message:"Time between system checks is too short, delaying")
            
            // clear the menu animation
            self.updateRunning = false
            
            if ( !updateScheduled ) {
                Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(updateUserInfo), userInfo: nil, repeats: false)
                
                updateScheduled = true
            }
        }
        //stopMenuAnimationTimer()
    }
}
