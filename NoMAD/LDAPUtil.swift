//
//  LDAPUtil.swift
//  NoMAD
//
//  Created by Joel Rennich on 6/27/16.
//  Copyright © 2016 Trusource Labs. All rights reserved.
//

import Foundation
import Cocoa

struct LDAPServer {
    var host: String
    var status: String
    var priority: Int
    var weight: Int
    var timeStamp: NSDate
}


class LDAPServers {
    
    // defaults
    
    var hosts = [LDAPServer]()
    var defaultNamingContext: String = ""
    var currentState: Bool = false
    var currentDomain = ""
    var current: Int = 0 {
        didSet(LDAPServer) {
            NSLog("Setting the current LDAP server to: " + hosts[current].host)
        }
    }
    
    func setDomain(domain: String) {
        
        if defaults.integerForKey("Verbose") >= 1 {
            NSLog("Finding LDAP Servers.")
        }
    
        currentDomain = domain
        
        // TODO: get the this working better
        //print(defaults.stringForKey("LDAPServerList"))
        
        guard (( defaults.stringForKey("LDAPServerList")) == nil ) else {

           let myLDAPServerListRaw = defaults.stringForKey("LDAPServerList")
            let myLDAPServerList = myLDAPServerListRaw?.componentsSeparatedByString(",")
            for server in myLDAPServerList! {
                let currentServer: LDAPServer = LDAPServer(host: server, status: "found", priority: 0, weight: 0, timeStamp: NSDate())
                hosts.append(currentServer)
                }
            currentState = true
            testHosts()
            return
            }
        
        getHosts(domain)
        // now to sort them if we got results
        
        if self.currentState {
        testHosts()
        }
        // TODO: use sites to figure out the "right" server to be using
        
    }
    
    // Return the current Domain
    
    func getDomain() -> String {
        
        if (currentDomain != "") {
            return currentDomain
        } else {
            return "not set"
        }
    }
    
    // Return the current server
    
    var currentServer: String {
        if self.currentState {
        return hosts[current].host
        } else {
            return ""
        }
    }
    
    // return the status of the current server
    
    var currentStatus: String {
        return hosts[current].status
    }
    
    func networkChange() {
        getHosts(currentDomain)
        testHosts()
    }
    
    // mark the current server as dead - this will redo the whole process
    // TODO: just re-test the non-dead servers
    
    func dead() {
        NSLog("Marking server as dead: " + hosts[current].host)
        hosts[current].status = "dead"
        hosts[current].timeStamp = NSDate()
        if (hosts.count > current) { testHosts() }
    }
    
    // return the whole list of servers
    
    func returnAll() -> [LDAPServer] {
        return hosts
    }
    
    // return just the servers currently marked dead
    
    func returnDead() -> [LDAPServer] {
        var results = [LDAPServer]()
        for i in 0...(hosts.count - 1) {
            if hosts[i].status == "dead" {
                results.append(hosts[i])
            }
        }
        
        return results
    }
    
    // return the current state 0 or 1
    
    func returnState() -> Bool {
        return self.currentState
    }
    
    // on network changes test to see if the LDAP server is still valid
    
    func check() {
        
        if testSocket(self.currentServer) && testLDAP(self.currentServer) {
            NSLog("Using same LDAP server: " + self.currentServer)
        } else {
            NSLog("Can't connect to LDAP server, finding new one")
            networkChange()
        }
        
    }
    
    // do an LDAP lookup with the current naming context
    
    func getLDAPInformation( attribute: String, baseSearch: Bool=false, searchTerm: String="") throws -> String {
        
        var myResult: String
        
        guard testSocket(self.currentServer) else {
            throw NoADError.LDAPServerLookup
        }
        
        if (defaultNamingContext == "") || (defaultNamingContext.containsString("GSSAPI Error")) {
            testHosts()
        }
        
        if baseSearch {
            myResult = cleanLDAPResults(cliTask("/usr/bin/ldapsearch -Q -LLL -s base -H ldap://" + self.currentServer + " -b " + self.defaultNamingContext + " " + searchTerm + " " + attribute), attribute: attribute)
        } else {
            myResult = cleanLDAPResults(cliTask("/usr/bin/ldapsearch -Q -LLL -H ldap://" + self.currentServer + " -b " + self.defaultNamingContext + " " + searchTerm + " " + attribute), attribute: attribute)
        }
        return myResult
    }
    
    func returnFullRecord(searchTerm: String) -> String {
        let myResult = cliTaskNoTerm("/usr/bin/ldapsearch -Q -LLL -H ldap://" + self.currentServer + " -b " + self.defaultNamingContext + " " + searchTerm )
        return myResult
    }
    
    // private function to clean the LDAP results
    
    private func cleanLDAPResults(result: String, attribute: String) -> String {
        let lines = result.componentsSeparatedByString("\n")
        
        var myResult = ""
        
        for i in lines {
            if (i.containsString(attribute)) {
                myResult = i.stringByReplacingOccurrencesOfString( attribute + ": ", withString: "")
                break
            }
        }
        return myResult
    }
    
    private func testSocket( host: String ) -> Bool {
        
        let mySocketResult = cliTask("/usr/bin/nc -G 5 -z " + host + " 389")
        if mySocketResult.containsString("succeeded!") {
            return true
        } else {
            return false
        }
    }
    
    private func testLDAP ( host: String ) -> Bool {
        
        if defaults.integerForKey("Verbose") >= 1 {
            NSLog("Testing " + host + ".")
        }
        
        let myLDAPResult = cliTask("/usr/bin/ldapsearch -LLL -Q -l 3 -s base -H ldap://" + host + " defaultNamingContext")
        if myLDAPResult != "" {
            defaultNamingContext = cleanLDAPResults(myLDAPResult, attribute: "defaultNamingContext")
            return true
        } else {
            return false
        }
    }
    
    // get the list of LDAP servers from an SRV lookup
    
    func getHosts(domain: String ) {
        
        var newHosts = [LDAPServer]()
        var dnsResults = cliTask("/usr/bin/dig +short +time=2 -t SRV _ldap._tcp." + domain).componentsSeparatedByString("\n")
        
        // check to make sure we got a result
        
        if dnsResults[0] == "" || dnsResults[0].containsString("connection timed out") {
            self.currentState = false
        } else {
            
            // check to make sure we didn't get a long TCP response
            
            if dnsResults[0].containsString("Truncated") {
                dnsResults.removeAtIndex(0)
            }
            
            for line in dnsResults {
                let host = line.componentsSeparatedByString(" ")
                if host[0] != "" {
                    let currentServer: LDAPServer = LDAPServer(host: host[3], status: "found", priority: Int(host[0])!, weight: Int(host[1])!, timeStamp: NSDate())
                    newHosts.append(currentServer)
                }
            }
            
            // now to sort them
            
            hosts = newHosts.sort { (x, y) -> Bool in
                return ( x.priority <= y.priority )
            }
            self.currentState = true
        }
    }
    
    // test the list of LDAP servers by iterating through them
    
    func testHosts() {
        if self.currentState == true {
            for i in 0...( hosts.count - 1) {
                if hosts[i].status != "dead" {
                    NSLog("Trying host: " + hosts[i].host)
                    
                    // socket test first - this could be falsely negative
                    // also note that this needs to return stderr
                    
                    let myPingResult = cliTask("/usr/bin/nc -G 5 -z " + hosts[i].host + " 389")
                    
                    if myPingResult.containsString("succeeded!") {
                        
                        // if socket test works, then atempt ldapsearch to get default naming context
                        
                        let myResult = cliTask("/usr/bin/ldapsearch -LLL -Q -l 3 -s base -H ldap://" + hosts[i].host + " defaultNamingContext")
                        if myResult != "" {
                            defaultNamingContext = cleanLDAPResults(myResult, attribute: "defaultNamingContext")
                            hosts[i].status = "live"
                            hosts[i].timeStamp = NSDate()
                            NSLog("Current LDAP Server is: " + hosts[i].host )
                            current = i
                            break
                        } else {
                            NSLog("Server is dead by way of ldap test: " + hosts[i].host)
                            hosts[i].status = "dead"
                            hosts[i].timeStamp = NSDate()
                            break
                        }
                    } else {
                        NSLog("Server is dead by way of socket test: " + hosts[i].host)
                        hosts[i].status = "dead"
                        hosts[i].timeStamp = NSDate()
                    }
                }
            }
        }
        
        guard ( hosts.count > 0 ) else {
            return
        }
        
        if hosts.last!.status == "dead" {
            self.currentState = false
        } else {
            self.currentState = true
        }
    }
    
}
