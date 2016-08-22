//
//  UserInformation.swift
//  NoMAD
//
//  Created by Joel Rennich on 8/20/16.
//  Copyright © 2016 Trusource Labs. All rights reserved.
//

import Foundation

class UserInformation {
    
    // set up defaults for the domain
    
    var status = "Not Connected"
    var domain = ""
    var realm = ""
    
    var passwordAging = false
    var connected = false
    var tickets = false
    
    // User Info
    var userShortName: String
    var userLongName: String
    var userPrincipal: String
    var userPrincipalShort: String
    var userPasswordSetDate = NSDate()
    var userPasswordExpireDate = NSDate()
    var userHome: String
    var userCertDate = NSDate()
    
    let myLDAPServers = LDAPServers()
    let myTickets = KlistUtil()
    
    init() {
        // zero everything out
        
        userShortName = ""
        userLongName = ""
        userPrincipal = ""
        userPrincipalShort = ""
        userPasswordSetDate = NSDate()
        userPasswordExpireDate = NSDate()
        userHome = ""
        userCertDate = NSDate()
    }
    
    func checkNetwork() -> Bool {
        myLDAPServers.check()
        return myLDAPServers.returnState()
    }
    
    func checkTickets() {
        
    }
    
    func getUserInfo() {
        
    }
}
