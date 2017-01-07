//
//  Preferences.swift
//  NoMAD
//
//  Created by Tom Nook on 11/12/16.
//  Copyright © 2016 Trusource Labs. All rights reserved.
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

    // displayName - r/o - string - the long name of the currently signed in user

    // exportableKey - r/w - bool - determines if the private key for a NoMAD-generated certificate can be exported - default is false

    // getHelpType - r/w - string - determines what method is triggered when a user selects the Get Help menu item
    // getHelp Options - r/w - string - options for configuring the actions of the selected getHelpType

    // groups - r/o - string - a list of AD groups that the currently signed in user is a member of

    // hidePrefs - r/w - bool - determines if the Preferences menu item should be shown

    // kerberosRealm - r/w - string - determines the Kerberos realm to use for all Kerberos activites. If left blank this will be set to the all-caps version of the AD Domain

    // keychainPasswordMatch - r/w - bool - determines if we should keep the keychain password the same as the login password if possible

    // lastCertificateExpiration - r/o - date - keeps track of the most future expiration date of certificates associated with the user's NT Principal for the Subj. Alternate Name on the certificate

    // loginItem - r/w - bool - if set to true will create a new Launch Agent for NoMAD. This will set itself back to false after being used

    // lDAPServerList - r/w - string - specifies a specfic or set of specific LDAP servers to be used instead of having NoMAD do the normal DNS and site lookups for the best AD Domain Controller

    // localPasswordSync - r/w - bool - determines if NoMAD will keep the network password in sync with the local user account password on the Mac

    // lastUser - r/o - string - used to stash the short name of the last signed in user. Used for autologin and other functions requiring persistance between sessions.

    // lastPasswordWarning - r/o - date - the date of the last time the user was warned that their password is about to expire. Used to keep track of how often to warn the user about their impending expiration.

    // lastPasswordExpireDate - r/o - date - an array of users and the date their password will expire. Used to keep track of passwords being changed outside of NoMAD.

    // passwordExpireAlertTime - r/w - date - when to start complaining about a password that is about to expire. Defaults to 1296000 secs or 15 days.

    // passwordChangeOptions - r/w - string - similar to getHelp, this sets options for the passwordChangeType to use
    // passwordChangeType - r/w - string - the method to use when the Change Password menu item is selected

    // renewTickets - r/w - bool - determines if NoMAD should auto-renew tickets

    // showHome - r/w - bool - determines if the user's network home share should be displayed as a menu item

    // secondsToRenew - r/w - int - determines the threshhold at which a ticket is renewed in seconds

    // selfServicePath - r/w - string - path to a self service application for "Get Software"

    // signInCommand - r/w - string - the shell script, or other binary, to be triggered whenever a succesful sign in occurs

    // stateChangeAction - r/w - string - the shell script, or other binary, to be triggered whenever the network changes

    // template - r/w - string - the certificate template to be used for an X509 enrollment

    // uPCAlert - r/w - bool - determines if we alert the user that the password was changed outside of NoMAD

    // userPrincipal - r/o - string - the Kerberos principal for the currently signed in user

    // userPasswordExpireDate - r/o - date - the last time the user was warned about their password expiring ***

    // userCommandTask1 - r/w - string - path to command that will show up in the menu
    // userCommandName1 - r/w - string - name for the menu item that will trigger userCommandTask1
    // userCommandHotKey - r/w - string - hotkey to assign the userCommandName

    // userPasswordSetDate - r/o - string - list of users and dates that their passwords were last set in AD

    // userKeychain - r/w - bool - determines if NoMAD saves the user's password into the user's keychian and then autologin with that

    // userAging - r/o - bool - flag that shows if the user's password can expire

    // userShortName - r/o - string - the user's short name as pulled from AD

    // verbose - r/w - bool - determines if verbose logging is enabled or not
    
    // x509CA - r/w - string - URL for the Windows WebCA for certificate generation

    static let aDDomain = "ADDomain"
    static let autoConfigure = "AutoConfigure"
    static let changePasswordType = "ChangePasswordType"
    static let caribouTime = "CaribouTime"
    static let configureChrome = "ConfigureChrome"
    static let displayName = "DisplayName"
    static let exportableKey = "ExportableKey"
    static let getHelpType = "GetHelpType"
    static let getHelpOptions = "GetHelpOptions"
    static let groups = "Groups"
    static let hidePrefs = "HidePrefs"
    static let kerberosRealm = "KerberosRealm"
    static let keychainPasswordMatch = "KeychainPasswordMatch"
    static let lastCertificateExpiration = "LastCertificateExpiration"
    static let loginComamnd = "LoginComamnd"
    static let loginItem = "LoginItem"
    static let lDAPServerList = "LDAPServerList"
    static let localPasswordSync = "LocalPasswordSync"
    static let lastUser = "LastUser"
    static let lastPasswordWarning = "LastPasswordWarning"
    static let lastPasswordExpireDate = "LastPasswordExpireDate"
    static let messageLocalSync = "MessageLocalSync"
    static let passwordExpireAlertTime = "PasswordExpireAlertTime"
    static let passwordChangeOptions = "PasswordChangeOptions"

    /// Should NoMAD automatically attempt to renew Kerberos tickets on behalf of the user.
    static let renewTickets = "RenewTickets"

    /// Should NoMAD automatically attempt to mount the user's AD defined home share.
    static let showHome = "ShowHome"
    static let secondsToRenew = "SecondsToRenew"
    static let selfServicePath = "SelfServicePath"
    static let signInCommand = "SignInCommand"
    static let stateChangeAction = "StateChangeAction"
    static let template = "Template"
    static let uPCAlert = "UPCAlert"
    static let userPrincipal = "UserPrincipal"
    static let userHome = "UserHome"
    static let userPasswordExpireDate = "UserPasswordExpireDate"
    static let userCommandTask1 = "UserCommandTask1"
    static let userCommandName1 = "UserCommandName1"
    static let userCommandHotKey1 = "UserCommandHotKey1"
    static let userPasswordSetDates = "UserPasswordSetDates"
    static let useKeychain = "UseKeychain"
    static let userAging = "UserAging"
    static let userShortName = "UserShortName"

    /// Should verbose logging be used. This will significantly increase log spew.
    static let verbose = "Verbose"
    static let x509CA = "X509CA"
}
