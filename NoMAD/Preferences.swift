//
//  Preferences.swift
//  NoMAD
//
//  Created by Tom Nook on 11/12/16.
//  Copyright © 2016 Trusource Labs. All rights reserved.
//


/// A convenience name for `UserDefaults.standard`
let defaults = UserDefaults.standard

enum Preferences {
    static let aDDomain = "ADDomain"
    static let autoConfigure = "AutoConfigure"
    static let displayName = "DisplayName"
    static let expeditedLookup = "ExpeditedLookup"
    static let getHelpType = "GetHelpType"
    static let getHelpOptions = "GetHelpOptions"
    static let groups = "Groups"
    static let hidePrefs = "HidePrefs"
    static let kerberosRealm = "KerberosRealm"
    static let lastCertificateExpiration = "LastCertificateExpiration"
    static let loginComamnd = "LoginComamnd"
    static let loginItem = "LoginItem"
    static let lDAPServerList = "LDAPServerList"
    static let localPasswordSync = "LocalPasswordSync"
    static let lastUser = "LastUser"
    static let lastPasswordWarning = "LastPasswordWarning"
    static let passwordExpireAlertTime = "PasswordExpireAlertTime"
    static let renewTickets = "RenewTickets"
    static let showHome = "ShowHome"
    static let secondsToRenew = "SecondsToRenew"
    static let signInCommand = "SignInCommand"
    static let stateChangeAction = "StateChangeAction"
    static let template = "Template"
    static let userPrincipal = "UserPrincipal"
    static let userPasswordExpireDate = "UserPasswordExpireDate"
    static let userCommandTask1 = "UserCommandTask1"
    static let userCommandName1 = "UserCommandName1"
    static let userCommandHotKey1 = "UserCommandHotKey1"
    static let userPasswordSetDates = "UserPasswordSetDates"
    static let useKeychain = "UseKeychain"
    static let userAging = "UserAging"
    static let verbose = "Verbose"
    static let x509CA = "X509CA"
}
