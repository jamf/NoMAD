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
				findSite()
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
                findSite()
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
                findSite()
            }
        } else {
            if tickets.state {
                myLogger.logit(0, message:"Can't connect to LDAP server, finding new one")
            }
        networkChange()
        }
        
    }
    
    // do an LDAP lookup with the current naming context
    
	func getLDAPInformation( attributes: [String], baseSearch: Bool=false, searchTerm: String="", test: Bool=true, overrideDefaultNamingContext: Bool=false) throws -> [[String:String]] {
        
        if test {
            guard testSocket(self.currentServer) else {
                throw NoADError.LDAPServerLookup
            }
        }
		
		// TODO: We need to un-comment this and figure out another way to pass a valid empty defaultNamingContext
		if (overrideDefaultNamingContext == false) {
			if (defaultNamingContext == "") || (defaultNamingContext.containsString("GSSAPI Error")) {
				testHosts()
			}
		}
		let command = "/usr/bin/ldapsearch"
		var arguments: [String] = [String]()
		arguments.append("-N")
		arguments.append("-Q")
		arguments.append("-LLL")
		arguments.append("-o")
		arguments.append("nettimeout=1")
		arguments.append("-o")
		arguments.append("ldif-wrap=no")
		if baseSearch {
			arguments.append("-s")
			arguments.append("base")
		}
		arguments.append("-H")
		arguments.append("ldap://" + self.currentServer)
		arguments.append("-b")
		arguments.append(self.defaultNamingContext)
		if ( searchTerm != "") {
			arguments.append(searchTerm)
		}
		arguments.appendContentsOf(attributes)
		let ldapResult = cliTask(command, arguments: arguments)
		
		if (ldapResult.containsString("GSSAPI Error") || ldapResult.containsString("Can't contact")) {
			throw NoADError.LDAPConnectionError
		}
		
		let myResult = cleanLDIF(ldapResult)
	
		/*
		if baseSearch {
			myResult = cleanLDAPResults(ldapResult, attributesFilter: attributes)
		} else {
			myResult = cleanLDAPResultsMultiple(ldapResult, attribute: attributes[0])
		}
		*/
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
	
	private func findSite() {
		// backup the defaultNamingContext so we can restore it at the end.
		let tempDefaultNamingContext = defaultNamingContext
		
		// Setting defaultNamingContext to "" because we're doing a search against the RootDSE
		defaultNamingContext = ""

		
		// For info on LDAP Ping: https://msdn.microsoft.com/en-us/library/cc223811.aspx
		// For information on the values: https://msdn.microsoft.com/en-us/library/cc223122.aspx
		let attribute = "netlogon"
		// not sure if we need: (AAC=\00\00\00\00)
		let searchTerm = "(&(DnsDomain=\(currentDomain))(NtVer=\\06\\00\\00\\00))" //NETLOGON_NT_VERSION_WITH_CLOSEST_SITE
		
		guard let ldifResult = try? getLDAPInformation([attribute], baseSearch: true, searchTerm: searchTerm, test: false, overrideDefaultNamingContext: true) else {
			myLogger.logit(LogLevel.base, message: "LDAP Query failed.")
			myLogger.logit(LogLevel.debug, message:"Resetting default naming context to: " + defaultNamingContext)
			defaultNamingContext = tempDefaultNamingContext
			return
		}
		let ldapPingBase64 = getAttributeForSingleRecordFromCleanedLDIF(attribute, ldif: ldifResult)
		
		if ldapPingBase64 == "" {
			myLogger.logit(LogLevel.base, message: "ldapPingBase64 is empty.")
			myLogger.logit(LogLevel.debug, message:"Resetting default naming context to: " + defaultNamingContext)
			defaultNamingContext = tempDefaultNamingContext
			return
		}
		
		guard let ldapPing: ADLDAPPing = ADLDAPPing(ldapPingBase64String: ldapPingBase64) else {
			myLogger.logit(LogLevel.debug, message:"Resetting default naming context to: " + defaultNamingContext)
			defaultNamingContext = tempDefaultNamingContext
			return
		}
		
		site = ldapPing.clientSite ?? ""
		
		
		if (ldapPing.flags.contains(.DS_CLOSEST_FLAG)) {
			myLogger.logit(LogLevel.info, message:"The current server is the closest server.")
		} else {
			if ( site != "") {
				myLogger.logit(LogLevel.info, message:"Site \"\(site)\" found.")
				myLogger.logit(LogLevel.notice, message: "Looking up DCs for site.")
				//let domain = currentDomain
				let currentHosts = hosts
				getHosts(currentDomain)
				if (hosts[0].host == "") {
					myLogger.logit(LogLevel.base, message: "Site \"\(site)\" has no DCs configured. Ignoring site. You should fix this.")
					hosts = currentHosts
				}
				testHosts()
			} else {
				myLogger.logit(LogLevel.base, message: "Unable to find site")
			}
		}
		myLogger.logit(LogLevel.debug, message:"Resetting default naming context to: " + defaultNamingContext)
		defaultNamingContext = tempDefaultNamingContext
	}
	
	
	
	private func cleanLDIF(ldif: String) -> [[String:String]] {
		//var myResult = [[String:String]]()
		
		var ldifLines: [String] = ldif.componentsSeparatedByCharactersInSet(NSCharacterSet.newlineCharacterSet())
		
		var records = [[String:String]]()
		var record = [String:String]()
		var attributes = Set<String>()
		
		for var i in 0..<ldifLines.count {
			// save current lineIndex
			let lineIndex = i
			ldifLines[lineIndex] = ldifLines[lineIndex].trim()
			
			// skip version
			if i == 0 && ldifLines[lineIndex].hasPrefix("version") {
				continue
			}
			
			if !ldifLines[lineIndex].isEmpty {
				// fold lines
				
				while i+1 < ldifLines.count && ldifLines[i+1].hasPrefix(" ") {
					ldifLines[lineIndex] += ldifLines[i+1].trim()
					i += 1
				}
			} else {
				// end of record
				if (record.count > 0) {
					records.append(record)
				}
				record = [String:String]()
			}
			
			// skip comment
			if ldifLines[lineIndex].hasPrefix("#") {
				continue
			}
			
			var attribute = ldifLines[lineIndex].characters.split(":", maxSplit: 1, allowEmptySlices: true).map(String.init)
			if attribute.count == 2 {
				
				// Get the attribute name (before ;),
				// then add to attributes array if it doesn't exist.
				var attributeName = attribute[0].trim()
				if let index = attributeName.characters.indexOf(";") {
					attributeName = attributeName.substringToIndex(index)
				}
				if !attributes.contains(attributeName) {
					attributes.insert(attributeName)
				}
				
				// Get the attribute value.
				// Check if it is a URL (<), or base64 string (:)
				var attributeValue = attribute[1].trim()
				// If
				if attributeValue.hasPrefix("<") {
					// url
					attributeValue = attributeValue.substringFromIndex(attributeValue.startIndex.successor()).trim()
				} else if attributeValue.hasPrefix(":") {
					// base64
					let tempAttributeValue = attributeValue.substringFromIndex(attributeValue.startIndex.successor()).trim()
					if (NSData(base64EncodedString: tempAttributeValue, options: NSDataBase64DecodingOptions.init(rawValue: 0)) != nil) {
						attributeValue = tempAttributeValue
					} else {
						attributeValue = ""
					}
				}
				
				// escape double quote
				attributeValue = attributeValue.stringByReplacingOccurrencesOfString("\"", withString: "\"\"")
				
				// save attribute value or append it to the existing
				if let val = record[attributeName] {
					//record[attributeName] = "\"" + val.substringWithRange(Range<String.Index>(start: val.startIndex.successor(), end: val.endIndex.predecessor())) + ";" + attributeValue + "\""
					record[attributeName] = val + ";" + attributeValue
				} else {
					record[attributeName] = attributeValue
				}
			}
		}
		// save last record
		if record.count > 0 {
			records.append(record)
		}
		
		return records
	}
	
	func getAttributeForSingleRecordFromCleanedLDIF(attribute: String, ldif: [[String:String]]) -> String {
		var result: String = ""
		
		var foundAttribute = false
		
		for record in ldif {
			for (key, value) in record {
				if attribute == key {
					foundAttribute = true
					result = value
					break;
				}
			}
			if (foundAttribute == true) {
				break;
			}
		}
		return result
	}
	
	func getAttributesForSingleRecordFromCleanedLDIF(attributes: [String], ldif: [[String:String]]) -> [String:String] {
		var results = [String: String]()
		
		var foundAttribute = false
		for record in ldif {
			for (key, value) in record {
				if attributes.contains(key) {
					foundAttribute = true
					results[key] = value
				}
			}
			if (foundAttribute == true) {
				break;
			}
		}
		return results
	}
	
	/*
    private func cleanLDAPResults(result: String, attribute: String) -> String {
        var myResult = ""
	
		let lines = result.componentsSeparatedByString("\n")
	
		for i in lines {
		if (i.containsString(attribute)) {
                myResult = line.stringByReplacingOccurrencesOfString( attribute + ": ", withString: "")
                break
            }
	
        }
        return myResult
    }
    */
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
        let attribute = "defaultNamingContext"
        let myLDAPResult = cliTask("/usr/bin/ldapsearch -N -LLL -Q -l 3 -s base -H ldap://" + host + " " + attribute)
		if myLDAPResult != "" && !myLDAPResult.containsString("GSSAPI Error") && !myLDAPResult.containsString("Can't contact") {
			let ldifResult = cleanLDIF(myLDAPResult)
			if ( ldifResult.count > 0 ) {
				defaultNamingContext = getAttributeForSingleRecordFromCleanedLDIF(attribute, ldif: ldifResult)
				return true
			}
		}
		return false
	}
    
    // this checks to see if we can get SRV records for the domain
    
    private func checkConnectivity( domain: String ) -> Bool {
        
        self.resolver.queryType = "SRV"
		self.resolver.queryValue = "_ldap._tcp." + domain
		if (site != "") {
			self.resolver.queryValue = "_ldap._tcp." + site + "._sites." + domain
		}
		
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
		if (site != "") {
			self.resolver.queryValue = srv_type + site + "._sites." + domain
		}
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
		if (site != "") {
			self.resolver.queryValue = "_ldap._tcp." + site + "._sites." + domain
		}
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
                        let attribute = "defaultNamingContext"
                        let myLDAPResult = cliTaskNoTerm("/usr/bin/ldapsearch -N -LLL -Q -l 3 -s base -H ldap://" + hosts[i].host + " " + attribute)
                        if myLDAPResult != "" && !myLDAPResult.containsString("GSSAPI Error") && !myLDAPResult.containsString("Can't contact") {
							let ldifResult = cleanLDIF(myLDAPResult)
							if ( ldifResult.count > 0 ) {
								defaultNamingContext = getAttributeForSingleRecordFromCleanedLDIF(attribute, ldif: ldifResult)
								hosts[i].status = "live"
								hosts[i].timeStamp = NSDate()
								myLogger.logit(0, message:"Current LDAP Server is: " + hosts[i].host )
								myLogger.logit(0, message:"Current default naming context: " + defaultNamingContext )
								current = i
								break
							}
						}
						// We didn't get an actual LDIF Result... so LDAP isn't working.
						myLogger.logit(1, message:"Server is dead by way of ldap test: " + hosts[i].host)
						hosts[i].status = "dead"
						hosts[i].timeStamp = NSDate()
						break
						
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
