//
//  LDAPUtil.swift
//  NoMAD
//
//  Created by Joel Rennich on 6/27/16.
//  Copyright © 2016 Trusource Labs. All rights reserved.
//

import Foundation
import Cocoa
import SystemConfiguration
// import dnssd

struct LDAPServer {
    var host: String
    var status: String
    var priority: Int
    var weight: Int
    var timeStamp: NSDate
}

class LDAPServers : NSObject, DNSResolverDelegate {
    // defaults
    
    var hosts = [LDAPServer]()
    var defaultNamingContext: String
    var currentState: Bool
    var currentDomain : String
    var lookupServers: Bool
    var site: String
    let store = SCDynamicStoreCreate(nil, NSBundle.mainBundle().bundleIdentifier!, nil, nil)
    
    var lastNetwork = ""
    
    let tickets = KlistUtil()
    
    var current: Int {
        didSet(LDAPServer) {
            myLogger.logit(0, message:"Setting the current LDAP server to: " + hosts[current].host)
        }
    }
    
    // on init zero everything out
    
    override init() {
        defaultNamingContext = ""
        currentState = false
        currentDomain = ""
        lookupServers = true
        site = ""
        current = 0
		
		self.resolver = DNSResolver.init()
        //myLogger.logit(2, message:"Looking up tickets.")
        //tickets.getDetails()
    }
    
    // this sets the default domain, will take an optional value to determine if the user has a TGT for the domain
    
    func setDomain(domain: String) {
        
        myLogger.logit(0, message:"Finding LDAP Servers.")
        
        // set the domain to the current AD Domain
        
        currentDomain = domain
        
        // if a static LDAP server list is given, we don't need to do any testing
        
        if ( (defaults.stringForKey("LDAPServerList") ?? "") != "" ) {
            
            let myLDAPServerListRaw = defaults.stringForKey("LDAPServerList")
            let myLDAPServerList = myLDAPServerListRaw?.componentsSeparatedByString(",")
            for server in myLDAPServerList! {
                let currentServer: LDAPServer = LDAPServer(host: server, status: "found", priority: 0, weight: 0, timeStamp: NSDate())
                hosts.append(currentServer)
            }
            currentState = true
            lookupServers = false
            site = "static"
            
            if tickets.state {
                testHosts()
            }
            
        } else {
            
            // check if we're connected
                
                getHosts(domain)
                
                // now to sort them if we received results
                
                if self.currentState && tickets.state {
                    testHosts()
                    do {
                        try findSite()
                    } catch {
                        myLogger.logit(0, message: "Site lookup failed")
                    }
            }
        }
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
        
        // on a network change we need to relook at things
        // if we have a static list of servers, use that
        
        tickets.getDetails()
        
        if defaults.stringForKey("LDAPServerList") != nil {
            
            // clear out the hosts list and reload it
            
            hosts.removeAll()
            
            let myLDAPServerListRaw = defaults.stringForKey("LDAPServerList")
            let myLDAPServerList = myLDAPServerListRaw?.componentsSeparatedByString(",")
            
            for server in myLDAPServerList! {
                let currentServer: LDAPServer = LDAPServer(host: server, status: "found", priority: 0, weight: 0, timeStamp: NSDate())
                hosts.append(currentServer)
            }
            
            currentState = true
            lookupServers = false
            site = "static"
            testHosts()
        } else {
            currentState = false
            site = ""
            getHosts(currentDomain)
            if self.currentState && tickets.state {
                testHosts()
                do {
                    try findSite()
                } catch {
                    myLogger.logit(0, message: "Site lookup failed")
                }
            }
        }
    }
    
    // mark the current server as dead - this will redo the whole process
    // TODO: just re-test the non-dead servers
    
    func dead() {
        myLogger.logit(1, message:"Marking server as dead: " + hosts[current].host)
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
        
        tickets.getDetails()
        
        if testSocket(self.currentServer) && testLDAP(self.currentServer) && tickets.state {
            
            if  defaultNamingContext != "" && site != "" {
                myLogger.logit(0, message:"Using same LDAP server: " + self.currentServer)
            } else {
                do {
                    try findSite()
                } catch {
                    myLogger.logit(0, message: "Site lookup failed")
                }
            }
        } else {
            if tickets.state {
                myLogger.logit(0, message:"Can't connect to LDAP server, finding new one")
            }
        networkChange()
        }
        
    }
    
    // do an LDAP lookup with the current naming context
    
    func getLDAPInformation( attribute: String, baseSearch: Bool=false, searchTerm: String="", test: Bool=true) throws -> String {
        
        var myResult: String
        
        if test {
            guard testSocket(self.currentServer) else {
                throw NoADError.LDAPServerLookup
            }
        }
        
        if (defaultNamingContext == "") || (defaultNamingContext.containsString("GSSAPI Error")) {
            testHosts()
        }
        
        if baseSearch {
            myResult = cleanLDAPResults(cliTask("/usr/bin/ldapsearch -N -Q -LLL -s base -H ldap://" + self.currentServer + " -b " + self.defaultNamingContext + " " + searchTerm + " " + attribute), attribute: attribute)
        } else {
            myResult = cleanLDAPResultsMultiple(cliTask("/usr/bin/ldapsearch -N -Q -LLL -H ldap://" + self.currentServer + " -b " + self.defaultNamingContext + " " + searchTerm + " " + attribute), attribute: attribute)
        }
        return myResult
    }
    
    func returnFullRecord(searchTerm: String) -> String {
        let myResult = cliTaskNoTerm("/usr/bin/ldapsearch -N -Q -LLL -H ldap://" + self.currentServer + " -b " + self.defaultNamingContext + " " + searchTerm )
        return myResult
    }
    
    // private function to resolve SRV records
    
    private func getSRV() {
        
    }
    
    // private function to get the AD site
    
    private func findSite() throws {
        
        myLogger.logit(2, message:"Looking for local IP")
        
        var found = false
        site = ""
        
        // first grab IPv4
        // TODO: fix for IPv6
        
        let network = getIPandMask()
        
        myLogger.logit(2, message:"IPs: " + network["IP"]![0])
        myLogger.logit(2, message:"Subnets: " + network["mask"]![0])
		
		// Save the normal naming context to a temp variable 
		// so we can restore it later
		let tempDefaultNamingContext = defaultNamingContext
		
		// Get Configuration Naming Context from LDAP
		var configurationNamingContext = ""
		let configurationLDAPResult = cliTask("/usr/bin/ldapsearch -N -LLL -Q -l 3 -s base -H ldap://" + currentServer + " configurationNamingContext")
		if configurationLDAPResult != "" && !configurationLDAPResult.containsString("GSSAPI Error") && !configurationLDAPResult.containsString("Can't contact") && !configurationLDAPResult.containsString("ldap_sasl_interactive_bind_s") {
			configurationNamingContext = cleanLDAPResults(configurationLDAPResult, attribute: "configurationNamingContext")
		}
		
		// If we were able to get the configuration naming context, then use it...
		if (configurationNamingContext != "") {
			myLogger.logit(2, message:"Using Configuration Naming Context")
			defaultNamingContext = "cn=Subnets,cn=Sites," + configurationNamingContext
		} else {
			myLogger.logit(2, message:"Using Default Naming Context")
			defaultNamingContext = "cn=Subnets,cn=Sites,cn=Configuration," + tempDefaultNamingContext
		}
		// Now look for sites
        let expeditedLookup = defaults.boolForKey("ExpeditedLookup")
        var subnetCount = 1000
        var subnetNetworks = [String]()
        
        if expeditedLookup {
            myLogger.logit(0, message:"Performing expedited site lookup.")
            subnetNetworks = try! getLDAPInformation("cn", baseSearch: false, searchTerm: "objectClass=subnet", test: false).componentsSeparatedByString(", ")
            subnetCount = subnetNetworks.count
        
            myLogger.logit(2, message:"Total number of subnets: " + String(subnetCount))
            myLogger.logit(3, message:"Subnets: " + String(subnetNetworks))
        } else {
            
        }
        
        // TODO: Support more than 1 local IP address
        //  for index in 1...IPs.count {
        
        var subMask = countBits(network["mask"]![0])
        let IPOctets = network["IP"]![0].componentsSeparatedByString(".")
        var IP = ""
        
        myLogger.logit(1, message:"Starting site lookups")
        
        // loop through all of the possible networks until we get a match, or fall through
        
        while subMask >= 0 && !found && subnetCount >= 2 {
            var networkBit = 0
            
            let octet = subMask / 8
            let octetMask = subMask % 8
            if subMask == 32 {
                networkBit = Int(IPOctets[3])!
        } else {
            networkBit = Int(IPOctets[octet])! - (Int(IPOctets[octet])! % binToDecimal(octetMask))
        }
        
            switch octet {
            case 0  : IP = String(networkBit) + ".0.0.0"
            case 1  : IP = IPOctets[0] + "." + String(networkBit) + ".0.0"
            case 2  : IP = IPOctets[0] + "." + IPOctets[1] + "." + String(networkBit) + ".0"
            case 3  : IP = IPOctets[0] + "." + IPOctets[1] + "." + IPOctets[2] + "." + String(networkBit)
            case 4  : IP = IPOctets[0] + "." + IPOctets[1] + "." + IPOctets[2] + "." + IPOctets[3]
            default : IP = IPOctets[0] + "." + IPOctets[1] + "." + IPOctets[2] + "." + IPOctets[3]
            }
            
            let currentNetwork = IP + "/" + String(subMask)
            
            myLogger.logit(3, message:"Current Network: " + currentNetwork)
            
            if currentNetwork == lastNetwork {
                myLogger.logit(1, message: "Network hasn't changed. Skipping site lookup")
                break
            }
            
            // if we are in expited mode we do the lookups locally
            if expeditedLookup {
                if subnetNetworks.contains(currentNetwork) {
                    myLogger.logit(3, message:"Current network found in subnet list.")
                    do {
                        myLogger.logit(3, message:"Trying site: cn=" + IP + "/" + String(subMask))
                        let siteTemp = try getLDAPInformation("siteObject", baseSearch: false, searchTerm: "cn=" + currentNetwork, test: false)
                        if siteTemp == "" {
                            myLogger.logit(3, message: "Site information was empty, ignoring site lookup.")
                        } else {
                            site = siteTemp
                        }
                        myLogger.logit(1, message:"Using site: " + site.componentsSeparatedByString(",")[0].stringByReplacingOccurrencesOfString("CN=", withString: ""))
                    }
                    catch {
                        myLogger.logit(0, message:"Error looking up site for network: " + currentNetwork)
                    }
                }
            } else {
                // see if we can find the network in AD
                do {
                    myLogger.logit(3, message:"Trying site: cn=" + IP + "/" + String(subMask))
                    let siteTemp = try getLDAPInformation("siteObject", baseSearch: false, searchTerm: "cn=" + currentNetwork, test: false)
                    if siteTemp == "" {
                        myLogger.logit(3, message: "Site information was empty, ignoring site.")
                    } else {
                        site = siteTemp
                    }
                    myLogger.logit(1, message:"Using site: " + site.componentsSeparatedByString(",")[0].stringByReplacingOccurrencesOfString("CN=", withString: ""))
                    }
                catch {
                    myLogger.logit(0, message:"Error looking up site for network: " + currentNetwork)
                }
            }
        
            if site != "" {
                myLogger.logit(3, message:"Site found, looking up DCs for site.")
                found = true
                let siteDomain = site.componentsSeparatedByString(",")[0].stringByReplacingOccurrencesOfString("CN=", withString: "") + "._sites." + currentDomain
                lastNetwork = currentNetwork
                
                // need to make sure the site has actual results
                
                let currentHosts = hosts
                getHosts(siteDomain)
                if hosts[0].host == "" {
                    myLogger.logit(0, message: "Site has no DCs configured. Ignoring site. You should fix this.")
                    hosts = currentHosts
                }
                testHosts()
            } else {
                subMask -= 1
                myLogger.logit(3, message:"No site found.")
            }

        }
        
        if site == "" {
            site = "No site found"
            myLogger.logit(0, message: "No matching sites found")
        }
        defaultNamingContext = tempDefaultNamingContext
        myLogger.logit(2, message:"Resetting default naming context to: " + defaultNamingContext)
    }
    
    // private function to get IP and mask
    
    private func getIPandMask() -> [String: [String]] {
        
        var network = [String: [String]]()
        
        // look for interface associated with a search domain of the AD domain
        
        let searchDomainKeysRaw = SCDynamicStoreCopyKeyList(store, "State:/Network/Service/.*/DNS")
        let searchDomainKeys: [AnyObject] = searchDomainKeysRaw! as [AnyObject]
        
        for key in searchDomainKeys {
            let myValues = SCDynamicStoreCopyValue(store, String(key) as CFString)
            
            if let searchDomain = myValues!["SupplementalMatchDomains"] {
                if searchDomain != nil {
                    
                    let searchDomain2 = myValues!["SupplementalMatchDomains"] as! [String]
                    if searchDomain2.contains(currentDomain) {
                        myLogger.logit(2, message: "Using domain-specific interface.")
                        
                        // get the interface GUID
                        let interfaceGUID = myValues!["ConfirmedServiceID"]
                        
                        // look up the service 
                        
                        let interfaceKey = "State:/Network/Service/" + (interfaceGUID!! as! String) + "/IPv4"
                        let domainInterface = SCDynamicStoreCopyValue(store, interfaceKey as CFString)
                        
                        // get the local IPs for it
                        
                        network["IP"] = domainInterface!["Addresses"] as! [String]
                        network["mask"] = ["255.255.255.254"]
                        return network
                    }
                }
            }
        }
        
        myLogger.logit(3, message: "Looking for primary interface.")
        
        let globalInterface = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4")
        let interface = globalInterface!["PrimaryInterface"] as! String
        
        myLogger.logit(3, message: "Primary interface is " + interface)
        
        let val = SCDynamicStoreCopyValue(store, "State:/Network/Interface/" + interface + "/IPv4") as! NSDictionary
        
        network["IP"] = (val["Addresses"] as! [String])
        guard (( val["SubnetMasks"] ) != nil) else {
            network["mask"] = ["255.255.255.254"]
            return network
        }
        network["mask"] = (val["SubnetMasks"] as! [String])
        return network
    }
    
    // private function to determine subnet mask for site determination
    
    private func countBits(mask: String) -> Int {
        var bits: Int
        switch mask {
        case "255.255.255.255": bits = 32
        case "255.255.255.254": bits = 31
        case "255.255.255.252": bits = 30
        case "255.255.255.248": bits = 29
        case "255.255.255.240": bits = 28
        case "255.255.255.224": bits = 27
        case "255.255.255.192": bits = 26
        case "255.255.255.128": bits = 25
        case "255.255.255.0"  : bits = 24
        case "255.255.254.0"  : bits = 23
        case "255.255.252.0"  : bits = 22
        case "255.255.248.0"  : bits = 21
        case "255.255.240.0"  : bits = 20
        case "255.255.224.0"  : bits = 19
        case "255.255.192.0"  : bits = 18
        case "255.255.128.0"  : bits = 17
        case "255.255.0.0"    : bits = 16
        case "255.254.0.0"    : bits = 15
        case "255.252.0.0"    : bits = 14
        case "255.248.0.0"    : bits = 13
        case "255.240.0.0"    : bits = 12
        case "255.224.0.0"    : bits = 11
        case "255.192.0.0"    : bits = 10
        case "255.128.0.0"    : bits = 9
        case "255.0.0.0"      : bits = 8
        case "254.0.0.0"      : bits = 7
        case "252.0.0.0"      : bits = 6
        case "248.0.0.0"      : bits = 5
        case "240.0.0.0"      : bits = 4
        case "224.0.0.0"      : bits = 3
        case "192.0.0.0"      : bits = 2
        case "128.0.0.0"      : bits = 1
        case "0.0.0.0"        : bits = 0
        default               : bits = 0
        }
        return bits
    }
    
    // private function to convert the mask length to a decimal
    
    private func binToDecimal(mask: Int) -> Int {
        var dec: Int
        switch mask {
        case 0  : dec = 256
        case 1  : dec = 128
        case 2  : dec = 64
        case 3  : dec = 32
        case 4  : dec = 16
        case 5  : dec = 8
        case 6  : dec = 4
        case 7  : dec = 2
        case 8  : dec = 1
        default : dec = 0
        }
        return dec
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
    
    // private function to clean the LDAP results if we're looking for multiple returns
    
    private func cleanLDAPResultsMultiple(result: String, attribute: String) -> String {
        let lines = result.componentsSeparatedByString("\n")
        
        var myResult = ""
        
        for i in lines {
            if (i.containsString(attribute)) {
                if myResult == "" {
                    myResult = i.stringByReplacingOccurrencesOfString( attribute + ": ", withString: "")
                } else {
                    myResult = myResult.stringByAppendingString( ", " + i.stringByReplacingOccurrencesOfString( attribute + ": ", withString: ""))
                }
            }
        }
        return myResult
    }
    
    // private function that uses netcat to create a socket connection to the LDAP server to see if it's reachable.
    // using ldapsearch for this can take a long time to timeout, this returns much quicker
    
    private func testSocket( host: String ) -> Bool {
        
        let mySocketResult = cliTask("/usr/bin/nc -G 5 -z " + host + " 389")
        if mySocketResult.containsString("succeeded!") {
            return true
        } else {
            return false
        }
    }
    
    // private function to test for an LDAP defaultNamingContext from the LDAP server
    // this tests for LDAP connectivity and gets the default naming context at the same time
    
    private func testLDAP ( host: String ) -> Bool {
        
        if defaults.integerForKey("Verbose") >= 1 {
            myLogger.logit(1, message:"Testing " + host + ".")
        }
        
        let myLDAPResult = cliTask("/usr/bin/ldapsearch -N -LLL -Q -l 3 -s base -H ldap://" + host + " defaultNamingContext")
        if myLDAPResult != "" && !myLDAPResult.containsString("GSSAPI Error") && !myLDAPResult.containsString("Can't contact") {
            defaultNamingContext = cleanLDAPResults(myLDAPResult, attribute: "defaultNamingContext")
            return true
        } else {
            return false
        }
    }
    
    // this checks to see if we can get SRV records for the domain
    
    private func checkConnectivity( domain: String ) -> Bool {

        //let dnsResults = cliTask("/usr/bin/dig +short -t SRV _ldap._tcp." + domain).componentsSeparatedByString("\n")
        
        self.resolver.queryType = "SRV"
        self.resolver.queryValue = "_ldap._tcp." + domain
        self.resolver.startQuery()
        
        while ( !self.resolver.finished ) {
            NSRunLoop.currentRunLoop().runMode(NSDefaultRunLoopMode, beforeDate: NSDate.distantFuture())
        }
        if (self.resolver.error == nil) {
            myLogger.logit(3, message: "Did Receive Query Result: " + self.resolver.queryResults.description)
            //let dnsResults = self.resolver.queryResults as! [[String:AnyObject]]
            currentState = true
            return true
        } else {
             myLogger.logit(2, message: "Can't find any SRV records for domain.")
            currentState = false
            return false
        }
    }
	
    func getSRVRecords(domain: String, srv_type: String="_ldap._tcp.") -> [String] {
        self.resolver.queryType = "SRV"
        self.resolver.queryValue = srv_type + domain
        var results = [String]()

        self.resolver.startQuery()
        
        while ( !self.resolver.finished ) {
            NSRunLoop.currentRunLoop().runMode(NSDefaultRunLoopMode, beforeDate: NSDate.distantFuture())
        }
        
        if (self.resolver.error == nil) {
            myLogger.logit(3, message: "Did Receive Query Result: " + self.resolver.queryResults.description)
            let records = self.resolver.queryResults as! [[String:AnyObject]]
            for record: Dictionary in records {
                let host = record["target"] as! String
                results.append(host)
            }
            
        } else {
            myLogger.logit(3, message: "Query Error: " + self.resolver.error.description)
        }
        return results
    }
	
	// get the list of LDAP servers from a SRV lookup
	// Uses DNSResolver
    
	func getHosts(domain: String ) {
		self.resolver.queryType = "SRV"
		self.resolver.queryValue = "_ldap._tcp." + domain
		self.resolver.startQuery()
		
		while ( !self.resolver.finished ) {
			NSRunLoop.currentRunLoop().runMode(NSDefaultRunLoopMode, beforeDate: NSDate.distantFuture())
		}
		
		if (self.resolver.error == nil) {
			myLogger.logit(3, message: "Did Receive Query Result: " + self.resolver.queryResults.description)
			
			var newHosts = [LDAPServer]()
			let records = self.resolver.queryResults as! [[String:AnyObject]]
			for record: Dictionary in records {
				let host = record["target"] as! String
				let priority = record["priority"] as! Int
				let weight = record["weight"] as! Int
				// let port = record["port"] as! Int
				let currentServer = LDAPServer(host: host, status: "found", priority: priority, weight: weight, timeStamp: NSDate())
				newHosts.append(currentServer)
			}
			
			// now to sort them
			
			hosts = newHosts.sort { (x, y) -> Bool in
				return ( x.priority <= y.priority )
			}
			self.currentState = true
			
		} else {
			myLogger.logit(3, message: "Query Error: " + self.resolver.error.description)
			self.currentState = false
			hosts.removeAll()
		}
	}

	/*
	// get the list of LDAP servers from an SRV lookup
	// Uses cliTask
    func getHosts(domain: String ) {
		// Testing DNSResolver.
		//self.resolver = DNSResolver.init(queryType: "SRV", andValue: "_ldap._tcp." + domain)
		self.resolver.queryType = "SRV"
		self.resolver.queryValue = "_ldap._tcp." + domain
		self.resolver.startQuery()
		
		while ( !self.resolver.finished ) {
			NSRunLoop.currentRunLoop().runMode(NSDefaultRunLoopMode, beforeDate: NSDate.distantFuture())
		}
		
		if (self.resolver.error == nil) {
			//print(self.resolver.queryResults.description)
			myLogger.logit(3, message: "Did Receive Query Result: " + self.resolver.queryResults.description)
		} else {
			//print(self.resolver.error.description)
			myLogger.logit(3, message: "Query Error: " + self.resolver.error.description)
		}
		
        var newHosts = [LDAPServer]()
        var dnsResults = cliTask("/usr/bin/dig +short -t SRV _ldap._tcp." + domain).componentsSeparatedByString("\n")
        
        // check to make sure we got a result
        
        if dnsResults[0] == "" || dnsResults[0].containsString("connection timed out") {
            self.currentState = false
            hosts.removeAll()
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
    */
	
    // test the list of LDAP servers by iterating through them
    
    func testHosts() {
        if self.currentState == true {
            for i in 0...( hosts.count - 1) {
                if hosts[i].status != "dead" {
                    myLogger.logit(1, message:"Trying host: " + hosts[i].host)
                    
                    // socket test first - this could be falsely negative
                    // also note that this needs to return stderr
                    
                    let mySocketResult = cliTask("/usr/bin/nc -G 5 -z " + hosts[i].host + " 389")
                    
                    if mySocketResult.containsString("succeeded!") {
                        
                        // if socket test works, then attempt ldapsearch to get default naming context
                        
                        let myResult = cliTaskNoTerm("/usr/bin/ldapsearch -N -LLL -Q -l 3 -s base -H ldap://" + hosts[i].host + " defaultNamingContext")
                        if myResult != "" {
                            defaultNamingContext = cleanLDAPResults(myResult, attribute: "defaultNamingContext")
                            hosts[i].status = "live"
                            hosts[i].timeStamp = NSDate()
                            myLogger.logit(0, message:"Current LDAP Server is: " + hosts[i].host )
                            myLogger.logit(0, message:"Current default naming context: " + defaultNamingContext )
                            current = i
                            break
                        } else {
                            myLogger.logit(1, message:"Server is dead by way of ldap test: " + hosts[i].host)
                            hosts[i].status = "dead"
                            hosts[i].timeStamp = NSDate()
                            break
                        }
                    } else {
                        myLogger.logit(1, message:"Server is dead by way of socket test: " + hosts[i].host)
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
            myLogger.logit(0, message: "All DCs in are dead! You should really fix this.")
            self.currentState = false
        } else {
            self.currentState = true
        }
    }
	
	// MARK: DNSResolver Delegate Methods
	var resolver: DNSResolver;
	
	func dnsResolver(resolver: DNSResolver!, didReceiveQueryResult queryResult: [NSObject : AnyObject]!) {
		myLogger.logit(3, message: "Did Recieve Query Result: " + queryResult.description);
	}

	func dnsResolver(resolver: DNSResolver!, didStopQueryWithError error: NSError!) {
		myLogger.logit(3, message: "Did Recieve Query Result: " + error.description);
	}
	
}
