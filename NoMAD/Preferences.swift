//
//  Preferences.swift
//  NoMAD
//
//  Created by Tom Nook on 11/12/16.
//  Copyright © 2016 Orchard & Grove Inc. All rights reserved.
//


/// A convenience name for `UserDefaults.standard`
let defaults = UserDefaults.standard

/// The preference keys for the NoMAD defaults domain.
///
/// Use these keys, rather than raw strings.
enum Preferences {


    // what the keys do

    // if they should be set by an admin (r/w) or are just used internally and put in defaults for admins to read (r/o)

    // type of data for the preference (string, bool, date, etc.)

    // aDDomain - r/w - string - the AD domain that is currently in use. Most of NoMAD's functionality is hinged off of this

    // autoConfigure - r/w - bool - whether to use the autoconfigure mechanisms to set all of the defaults. Handled by AutoConfigure.swift

    // configureChrome - r/w - bool - determines if we update the Chrome whitelisting for Kerberos auth

    // changePasswordCommand - r/w - string - script to run on successful password change

    // displayName - r/o - string - the long name of the currently signed in user

    // dontMatchKerbPrefs - r/w - bool - determines if kpasswd server is written out to kerb pref file during password change

    // exportableKey - r/w - bool - determines if the private key for a NoMAD-generated certificate can be exported - default is false

    // getCertAutomatically - r/w - bool - determines if a certificate is automatically requested for the user if one does not already exist

    // getHelpType - r/w - string - determines what method is triggered when a user selects the Get Help menu item
    // getHelp Options - r/w - string - options for configuring the actions of the selected getHelpType

    // groups - r/o - string - a list of AD groups that the currently signed in user is a member of

    // hideExpiration - r/w - bool - determines if NoMAD shows expiration dates to users or not

    // hideExpirationMessage - r/w - string - message to show in the menu bar for when your passowrd doesn't expire
    
    // hideCertificateNumber - number - hiding the "Get Certificate" option when this number of certificates is found
    
    // hideHelp - r/w - bool - determines if the Get Help menu item should be shown

    // hideLockScreen - r/w - bool - determines if the Lock Screen menu item should be shown

    // hidePrefs - r/w - bool - determines if the Preferences menu item should be shown

    // hideRenew - r/w - bool - determines if the Renew Tickets menu item should be shown

    // hideQuit = r/w - bool - determines if the Quit menu item should be shown
    
    // iconOff = r/w - string - file path to an icon for when you're off the network
    
    // iconOffDark = r/w - string - file path to an icon for when you're off the network
    
    // iconOn = r/w - string - file path to an icon for when you're on the network
    
    // iconOnDark = r/w - string - file path to an icon for when you're on the network

    // kerberosRealm - r/w - string - determines the Kerberos realm to use for all Kerberos activites. If left blank this will be set to the all-caps version of the AD Domain

    // keychainItems - r/w - [String] - Array of keychain item names to be synced when changing passwords
    // keychainPasswordMatch - r/w - bool - determines if we should keep the keychain password the same as the login password if possible

    // lastCertificateExpiration - r/o - date - keeps track of the most future expiration date of certificates associated with the user's NT Principal for the Subj. Alternate Name on the certificate

    // loginItem - r/w - bool - if set to true will create a new Launch Agent for NoMAD. This will set itself back to false after being used

    // lDAPSchema - r/w - String - determines what LDAP attributes to use if not using AD

    // lDAPServerList - r/w - string - specifies a specfic or set of specific LDAP servers to be used instead of having NoMAD do the normal DNS and site lookups for the best AD Domain Controller

    // localPasswordSync - r/w - bool - determines if NoMAD will keep the network password in sync with the local user account password on the Mac

    // localPasswordSyncOnMatchOnly - r/w - bool - only do the local password sync if the ad short name matches the local user name

    // lastUser - r/o - string - used to stash the short name of the last signed in user. Used for autologin and other functions requiring persistance between sessions.

    // lastPasswordWarning - r/o - date - the date of the last time the user was warned that their password is about to expire. Used to keep track of how often to warn the user about their impending expiration.

    // lastPasswordExpireDate - r/o - date - an array of users and the date their password will expire. Used to keep track of passwords being changed outside of NoMAD.
    
    // LocalPasswordSyncDontSyncLocalUsers - r/w - array - and array of AD user names that shouldn't have their password synced locally.
    
    // LocalPasswordSyncDontSyncNetworkUsers - r/w - array - and array of AD user names that shouldn't have their password synced locally.

    // LockedKeychainCheck - r/w - bool - check if the default keychain is locked

    // lDAPoverSSL - r/w - bool - flag to use LDAPS instead of LDAP

    // menuChangePassword - r/w - string - title of the Change Password menu

    // menuHomeDirectory - r/w - string - title of the Home Directory menu

    // menuGetHelp - r/w - string - title of the Get Help menu

    // menuGetSoftware - r/w - string - title of the Get Software menu

    // menuPasswordExpires - r/w - string - title of the Password Expires menu before someone logs in

    // menuRenewTickets - r/w - string - title of the Rewnew Tickets menu

    // menuUserName - r/w - string - title of the User Name menu before anyone is logged in
    
    // menuWelcome - r/w - string - path to the custom splash screen directory containing an index.html file and all the assets needed, must be locally stored on the machine

    // messageLocalSync - r/w - string - text to display when the user is asked for their local password to allow the local accont password to be synced from the network account

    // messageNotConnected - r/w - string - text to display in menu bar when not connected

    // messagePasswordChangePolicy - r/w - string - message to show the help button in the password change window

    // passwordExpireAlertTime - r/w - date - when to start complaining about a password that is about to expire. Defaults to 1296000 secs or 15 days.

    // passwordExpireCustomAlert - r/w - string - Custom alert to show in the menu bar instead of days to go.

    // passwordExpireCustomWarnTime - r/w - Int - Threshold days to show custom password expiration warning in yellow.

    // passwordExpireCustomAlertTime - r/w - Int - Threshold days to show custom password expiration warning in red.

    // passwordChangeOptions - r/w - string - similar to getHelp, this sets options for the passwordChangeType to use
    // passwordChangeType - r/w - string - the method to use when the Change Password menu item is selected

    // passwordPolicy - r/w - dictionary - password policy object to evaluate password complexity

    // persistExpiratin - r/w - bool - determines if the expiration date should be shown regardless of connectivity

    // renewTickets - r/w - bool - determines if NoMAD should auto-renew tickets

    // showHome - r/w - bool - determines if the user's network home share should be displayed as a menu item

    // secondsToRenew - r/w - int - determines the threshhold at which a ticket is renewed in seconds

    // selfServicePath - r/w - string - path to a self service application for "Get Software"

    // signedIn - r/o - bool - flag to show if a user is currently signed in

    // signInCommand - r/w - string - the shell script, or other binary, to be triggered whenever a succesful sign in occurs

    // signInWindowOnLaunch - r/w - bool - will show a sign in window on launch if there are no tickets

    // siteIgnore - r/w - bool - determines if NoMAD ignores the site that comes back from AD. Generally this will mean NoMAD will use the globally advertised DCs instead of a particular site's.

    // siteForce - r/w - bool - forces NoMAD to use a particular site

    // stateChangeAction - r/w - string - the shell script, or other binary, to be triggered whenever the network changes

    // template - r/w - string - the certificate template to be used for an X509 enrollment

    // titleSignIn - r/w - string - Title of the Sign In window

    // uPCAlert - r/w - bool - determines if we alert the user that the password was changed outside of NoMAD
    
    // uPCAlertAction - r/w - string - the shell script, or other binary, to be triggered on uPCAlert

    // userPrincipal - r/o - string - the Kerberos principal for the currently signed in user

    // userPasswordExpireDate - r/o - date - the last time the user was warned about their password expiring ***

    // userCommandTask1 - r/w - string - path to command that will show up in the menu
    // userCommandName1 - r/w - string - name for the menu item that will trigger userCommandTask1
    // userCommandHotKey - r/w - string - hotkey to assign the userCommandName

    // userPasswordSetDate - r/o - string - list of users and dates that their passwords were last set in AD

    // userKeychain - r/w - bool - determines if NoMAD saves the user's password into the user's keychian and then autologin with that

    // userAging - r/o - bool - flag that shows if the user's password can expire

    // userShortName - r/o - string - the user's short name as pulled from AD

    // userUPN - r/o - string - the current users UPN

    // verbose - r/w - bool - determines if verbose logging is enabled or not
    
    // x509CA - r/w - string - URL for the Windows WebCA for certificate generation

    static let aDDomain = "ADDomain"
    static let aDSite = "ADSite"                    // current AD site
    static let allowEAPOL = "AllowEAPOL"            // allow airportd and eapolclient access to generated private keys
    static let autoConfigure = "AutoConfigure"
    static let autoRenewCert = "AutoRenewCert"
    static let changePasswordCommand = "ChangePasswordCommand"
    static let changePasswordType = "ChangePasswordType"
    static let changePasswordOptions = "ChangePasswordOptions"
    static let caribouTime = "CaribouTime"
    static let cleanCerts = "CleanCerts"
    static let configureChrome = "ConfigureChrome"
    static let configureChromeDomain = "ConfigureChromeDomain"
    static let deadLDAPKillTickets = "DeadLDAPKillTickets"
    static let displayName = "DisplayName"
    static let dontMatchKerbPrefs = "DontMatchKerbPrefs"
    static let dontShowWelcome = "DontShowWelcome"
    static let dontShowWelcomeDefaultOn = "DontShowWelcomeDefaultOn"
    static let exportableKey = "ExportableKey"
    static let firstRunDone = "FirstRunDone"
    static let getCertAutomatically = "GetCertificateAutomatically"
    static let getHelpType = "GetHelpType"
    static let getHelpOptions = "GetHelpOptions"
    static let groups = "Groups"
    static let hicFix = "HicFix"
    static let hideAbout = "HideAbout"
    static let hideExpiration = "HideExpiration"
    static let hideExpirationMessage = "HideExpirationMessage"
    static let hideCertificateNumber = "HideCertificateNumber"
    static let hideHelp = "HideHelp"
    static let hideGetSoftware = "HideGetSoftware"
    static let hideLockScreen = "HideLockScreen"
    static let hideRenew = "HideRenew"
    static let hidePrefs = "HidePrefs"
    static let hideQuit = "HideQuit"
    static let hideSignOut = "HideSignOut"
    static let homeAppendDomain = "HomeAppendDomain"
    static let iconOff = "IconOff"
    static let iconOffDark = "IconOffDark"
    static let iconOn = "IconOn"
    static let iconOnDark = "IconOnDark"
    static let kerberosRealm = "KerberosRealm"
    static let keychainItems = "KeychainItems"
    static let keychainItemsCreateSerial = "KeychainItemsCreateSerial"
    static let keychainItemsDebug = "KeychainItemsDebug"
    static let keychainMinderWindowTitle = "KeychainMinderWindowTitle"
    static let keychainMinderWindowMessage = "KeychainMinderWindowMessage"
    static let keychainMinderShowReset = "KeychainMinderShowReset"
    static let keychainPasswordMatch = "KeychainPasswordMatch"
    static let lastCertificateExpiration = "LastCertificateExpiration"
    static let loginComamnd = "LoginComamnd"
    static let loginItem = "LoginItem"
    static let ldapAnonymous = "LDAPAnonymous"
    static let lDAPSchema = "LDAPSchema"
    static let lDAPServerList = "LDAPServerList"
    static let lDAPServerListDeny = "LDAPServerListDeny"
    static let lDAPoverSSL = "LDAPOverSSL"
    static let lDAPOnly = "LDAPOnly"
    static let lDAPType = "LDAPType"
    static let localPasswordSync = "LocalPasswordSync"
    static let localPasswordSyncDontSyncLocalUsers = "LocalPasswordSyncDontSyncLocalUsers"
    static let localPasswordSyncDontSyncNetworkUsers = "LocalPasswordSyncDontSyncNetworkUsers"
    static let localPasswordSyncOnMatchOnly = "LocalPasswordSyncOnMatchOnly"
    static let lockedKeychainCheck = "LockedKeychainCheck"
    static let lastUser = "LastUser"
    static let lastPasswordWarning = "LastPasswordWarning"
    static let lastPasswordExpireDate = "LastPasswordExpireDate"
    static let menuAbout = "MenuAbout"
    static let menuActions = "MenuActions"
    static let menuChangePassword = "MenuChangePassword"
    static let menuHomeDirectory = "MenuHomeDirectory"
    static let menuGetCertificate = "MenuGetCertificate"
    static let menuGetHelp = "MenuGetHelp"
    static let menuGetSoftware = "MenuGetSoftware"
    static let menuFileServers = "MenuFileServers"
    static let menuPasswordExpires = "MenuPasswordExpires"
    static let menuRenewTickets = "MenuRenewTickets"
    static let menuUserName = "MenuUserName"
    static let menuWelcome = "MenuWelcome"
    static let messageLocalSync = "MessageLocalSync"
    static let messageNotConnected = "MessageNotConnected"
    static let messageUPCAlert = "MessageUPCAlert"
    static let messagePasswordChangePolicy = "MessagePasswordChangePolicy"
    static let passwordExpirationDays = "PasswordExpirationDays"
    static let passwordExpireAlertTime = "PasswordExpireAlertTime"
    static let passwordExpireCustomAlert = "PasswordExpireCustomAlert"
    static let passwordExpireCustomWarnTime = "PasswordExpireCustomWarnTime"
    static let passwordExpireCustomAlertTime = "PasswordExpireCustomAlertTime"
    static let passwordPolicy = "PasswordPolicy"
    static let persistExpiration = "PersistExpiration"
    
    static let recursiveGroupLookup = "RecursiveGroupLookup"

    /// Should NoMAD automatically attempt to renew Kerberos tickets on behalf of the user.
    static let renewTickets = "RenewTickets"

    /// Should NoMAD automatically attempt to mount the user's AD defined home share.
    static let showHome = "ShowHome"
    static let secondsToRenew = "SecondsToRenew"
    static let selfServicePath = "SelfServicePath"
    static let signInCommand = "SignInCommand"
    static let signInWindowAlert = "SignInWindowAlert"
    static let signInWindowAlertTime = "SignInWindowAlertTime"
    static let signInWindowOnLaunch = "SignInWindowOnLaunch"
    static let signInWindowOnLaunchExclusions = "SignInWindowOnLaunchExclusions"
    static let signedIn = "SignedIn"
    static let signOutCommand = "SignOutCommand"
    static let siteIgnore = "SiteIgnore"
    static let siteForce = "SiteForce"
    static let stateChangeAction = "StateChangeAction"
    static let switchKerberosUser = "SwitchKerberosUser"
    static let template = "Template"
    static let titleSignIn = "TitleSignIn"
    static let uPCAlert = "UPCAlert"
    static let uPCAlertAction = "UPCAlertAction"
    static let userPrincipal = "UserPrincipal"
    static let userHome = "UserHome"
    static let userPasswordExpireDate = "UserPasswordExpireDate"
    static let userCommandTask1 = "UserCommandTask1"
    static let userCommandName1 = "UserCommandName1"
    static let userCommandHotKey1 = "UserCommandHotKey1"
    static let userPasswordSetDates = "UserPasswordSetDates"
    static let useKeychain = "UseKeychain"
    static let useKeychainPrompt = "UseKeychainPrompt"
    static let userAging = "UserAging"
    static let userEmail = "UserEmail"
    static let userShortName = "UserShortName"
    static let userUPN = "UserUPN"

    /// Should verbose logging be used. This will significantly increase log spew.
    static let verbose = "Verbose"
    static let wifiNetworks = "WifiNetworks"
    static let x509CA = "X509CA"

    static let allKeys = [
        Preferences.aDDomain,
        Preferences.aDSite,
        Preferences.allowEAPOL,
        Preferences.autoConfigure,
        Preferences.autoRenewCert,
        Preferences.changePasswordCommand,
        Preferences.changePasswordType,
        Preferences.changePasswordOptions,
        Preferences.caribouTime,
        Preferences.cleanCerts,
        Preferences.configureChrome,
        Preferences.configureChromeDomain,
        Preferences.deadLDAPKillTickets,
        Preferences.displayName,
        Preferences.dontMatchKerbPrefs,
        Preferences.dontShowWelcome,
        Preferences.dontShowWelcomeDefaultOn,
        Preferences.exportableKey,
        Preferences.firstRunDone,
        Preferences.getCertAutomatically,
        Preferences.getHelpType,
        Preferences.getHelpOptions,
        Preferences.groups,
        Preferences.hicFix,
        Preferences.hideAbout,
        Preferences.hideExpiration,
        Preferences.hideExpirationMessage,
        Preferences.hideCertificateNumber,
        Preferences.hideHelp,
        Preferences.hideGetSoftware,
        Preferences.hideLockScreen,
        Preferences.hideRenew,
        Preferences.hidePrefs,
        Preferences.hideQuit,
        Preferences.hideSignOut,
        Preferences.homeAppendDomain,
        Preferences.iconOff,
        Preferences.iconOffDark,
        Preferences.iconOn,
        Preferences.iconOnDark,
        Preferences.kerberosRealm,
        Preferences.keychainItems,
        Preferences.keychainItemsCreateSerial,
        Preferences.keychainItemsDebug,
        Preferences.keychainMinderWindowTitle,
        Preferences.keychainMinderWindowMessage,
        Preferences.keychainMinderShowReset,
        Preferences.keychainPasswordMatch,
        Preferences.lastCertificateExpiration,
        Preferences.loginComamnd,
        Preferences.loginItem,
        Preferences.ldapAnonymous,
        Preferences.lDAPSchema,
        Preferences.lDAPServerList,
        Preferences.lDAPServerListDeny,
        Preferences.lDAPoverSSL,
        Preferences.lDAPOnly,
        Preferences.lDAPType,
        Preferences.localPasswordSync,
        Preferences.localPasswordSyncDontSyncLocalUsers,
        Preferences.localPasswordSyncDontSyncNetworkUsers,
        Preferences.localPasswordSyncOnMatchOnly,
        Preferences.lockedKeychainCheck,
        Preferences.lastUser,
        Preferences.lastPasswordWarning,
        Preferences.lastPasswordExpireDate,
        Preferences.menuAbout,
        Preferences.menuActions,
        Preferences.menuChangePassword,
        Preferences.menuHomeDirectory,
        Preferences.menuGetCertificate,
        Preferences.menuGetHelp,
        Preferences.menuGetSoftware,
        Preferences.menuFileServers,
        Preferences.menuPasswordExpires,
        Preferences.menuRenewTickets,
        Preferences.menuUserName,
        Preferences.menuWelcome,
        Preferences.messageLocalSync,
        Preferences.messageNotConnected,
        Preferences.messageUPCAlert,
        Preferences.messagePasswordChangePolicy,
        //Preferences.mountSMBOpen,
        Preferences.passwordExpirationDays,
        Preferences.passwordExpireAlertTime,
        Preferences.passwordExpireCustomAlert,
        Preferences.passwordExpireCustomWarnTime,
        Preferences.passwordExpireCustomAlertTime,
        Preferences.passwordPolicy,
        Preferences.persistExpiration,
        Preferences.recursiveGroupLookup,
        Preferences.renewTickets,
        Preferences.showHome,
        Preferences.secondsToRenew,
        Preferences.selfServicePath,
        Preferences.signInCommand,
        Preferences.signInWindowAlert,
        Preferences.signInWindowAlertTime,
        Preferences.signInWindowOnLaunch,
        Preferences.signInWindowOnLaunchExclusions,
        Preferences.signedIn,
        Preferences.signOutCommand,
        Preferences.siteIgnore,
        Preferences.siteForce,
        Preferences.stateChangeAction,
        Preferences.switchKerberosUser,
        Preferences.template,
        Preferences.titleSignIn,
        Preferences.uPCAlert,
        Preferences.uPCAlertAction,
        Preferences.userPrincipal,
        Preferences.userHome,
        Preferences.userPasswordExpireDate,
        Preferences.userCommandTask1,
        Preferences.userCommandName1,
        Preferences.userCommandHotKey1,
        Preferences.userPasswordSetDates,
        Preferences.useKeychain,
        Preferences.useKeychainPrompt,
        Preferences.userAging,
        Preferences.userEmail,
        Preferences.userShortName,
        Preferences.userUPN,
        Preferences.verbose,
        Preferences.wifiNetworks,
        Preferences.x509CA,
        //Preferences.x509Name,
        ]
}

func printAllPrefs() {
    print("--NoMAD Preferences--")
    
    for key in Preferences.allKeys {
        
        let pref = defaults.object(forKey: key) as AnyObject
        
        switch String(describing: type(of: pref)) {
        case "__NSCFBoolean" :
            print("\t" + key + ": " + String(describing: ( defaults.bool(forKey: key))))
        case "__NSCFArray" :
            print("\t" + key + ": " + ( String(describing: (defaults.array(forKey: key)!))))
        case "__NSTaggedDate":
            print("\t" + key + ": " + ( defaults.object(forKey: key) as! Date ).description(with: Locale.current))
        default :
            print("\t" + key + ": " + ( defaults.object(forKey: key) as? String ?? "Unset"))
        }
        
        if defaults.objectIsForced(forKey: key) {
            print("\t\tForced")
        }
    }
}
