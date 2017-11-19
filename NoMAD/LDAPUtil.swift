//
//  LDAPUtil.swift
//  NoMAD
//
//  Created by Joel Rennich on 6/27/16.
//  Copyright © 2016 Orchard & Grove Inc. All rights reserved.
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
    var timeStamp: Date
}

class LDAPServers : NSObject, DNSResolverDelegate {
    // defaults

    var hosts = [LDAPServer]()
    var defaultNamingContext: String
    var currentState: Bool
    var currentDomain : String
    var lookupServers: Bool
    var site: String
    let store = SCDynamicStoreCreate(nil, Bundle.main.bundleIdentifier! as CFString, nil, nil)

    var lastNetwork = ""

    let myDNSQueue = DispatchQueue(label: "com.trusourcelabs.NoMAD.background_dns_queue", attributes: [])

    var URIPrefix = "ldap://"
    var port = "389"
    var maxSSF = ""

    let tickets = KlistUtil()

    var current: Int {
        didSet(LDAPServer) {
            myLogger.logit(.base, message:"Setting the current LDAP server to: " + hosts[current].host)
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

        if defaults.bool(forKey: Preferences.lDAPoverSSL) {
            URIPrefix = "ldaps://"
            port = "636"
            maxSSF = "-O maxssf=0 "
        }

        //myLogger.logit(.notice, message:"Looking up tickets.")
        //tickets.getDetails()
    }

    // this sets the default domain, will take an optional value to determine if the user has a TGT for the domain

    func setDomain(_ domain: String) {

        myLogger.logit(.base, message:"Finding LDAP Servers.")

        // set the domain to the current AD Domain

        currentDomain = domain

        // if a static LDAP server list is given, we don't need to do any testing

        if (defaults.string(forKey: Preferences.lDAPServerList) != "" ) {

            let myLDAPServerListRaw = defaults.string(forKey: Preferences.lDAPServerList)
            let myLDAPServerList = myLDAPServerListRaw?.components(separatedBy: ",")
            for server in myLDAPServerList! {
                let currentServer: LDAPServer = LDAPServer(host: server, status: "found", priority: 0, weight: 0, timeStamp: Date())
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

        tickets.klist()

        if defaults.string(forKey: Preferences.lDAPServerList) != "" {

            // clear out the hosts list and reload it

            hosts.removeAll()

            let myLDAPServerListRaw = defaults.string(forKey: Preferences.lDAPServerList)
            let myLDAPServerList = myLDAPServerListRaw?.components(separatedBy: ",")

            for server in myLDAPServerList! {
                let currentServer: LDAPServer = LDAPServer(host: server, status: "found", priority: 0, weight: 0, timeStamp: Date())
                hosts.append(currentServer)
            }

            currentState = true
            lookupServers = false
            site = "static"
            
            if tickets.state {
                testHosts()
            }
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
        myLogger.logit(.info, message:"Marking server as dead: " + hosts[current].host)
        hosts[current].status = "dead"
        hosts[current].timeStamp = Date()
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

        tickets.klist()

        if testSocket(self.currentServer) && testLDAP(self.currentServer) && tickets.state {

            if  defaultNamingContext != "" && site != "" {
                myLogger.logit(.base, message:"Using same LDAP server: " + self.currentServer)
            } else {
                findSite()
            }
        } else {
            if tickets.state {
                myLogger.logit(.base, message:"Can't connect to LDAP server, finding new one")
            }
            networkChange()
        }

    }

    // do an LDAP lookup with the current naming context

    func getLDAPInformation( _ attributes: [String], baseSearch: Bool=false, searchTerm: String="", test: Bool=true, overrideDefaultNamingContext: Bool=false) throws -> [[String:String]] {

        if test {
            guard testSocket(self.currentServer) else {
                throw NoADError.ldapServerLookup
            }
        }

        // TODO: We need to un-comment this and figure out another way to pass a valid empty defaultNamingContext
        if (overrideDefaultNamingContext == false) {
            if (defaultNamingContext == "") || (defaultNamingContext.contains("GSSAPI Error")) {
                testHosts()
            }
        }

        // ensure we're using the right kerberos credential cache
        swapPrincipals(false)

        let command = "/usr/bin/ldapsearch"
        var arguments: [String] = [String]()
        arguments.append("-N")
        if defaults.bool(forKey: Preferences.ldapAnonymous) {
            arguments.append("-x")
        } else {
        arguments.append("-Q")
        }
        arguments.append("-LLL")
        arguments.append("-o")
        arguments.append("nettimeout=1")
        arguments.append("-o")
        arguments.append("ldif-wrap=no")
        if baseSearch {
            arguments.append("-s")
            arguments.append("base")
        }
        if maxSSF != "" {
            arguments.append("-O")
            arguments.append("maxssf=0")
        }
        arguments.append("-H")
        arguments.append(URIPrefix + self.currentServer)
        arguments.append("-b")
        arguments.append(self.defaultNamingContext)
        if ( searchTerm != "") {
            arguments.append(searchTerm)
        }
        arguments.append(contentsOf: attributes)
        let ldapResult = cliTask(command, arguments: arguments)

        if (ldapResult.contains("GSSAPI Error") || ldapResult.contains("Can't contact")) {
            throw NoADError.ldapConnectionError
        }

        let myResult = cleanLDIF(ldapResult)

        swapPrincipals(true)

        /*
         if baseSearch {
         myResult = cleanLDAPResults(ldapResult, attributesFilter: attributes)
         } else {
         myResult = cleanLDAPResultsMultiple(ldapResult, attribute: attributes[0])
         }
         */
        return myResult
    }

    func returnFullRecord(_ searchTerm: String) -> String {
        // ensure we're using the right kerberos credential cache
        swapPrincipals(false)

        let myResult = cliTaskNoTerm("/usr/bin/ldapsearch -N -Q -LLL " + maxSSF + "-H " + URIPrefix + self.currentServer + " -b " + self.defaultNamingContext + " " + searchTerm )
        swapPrincipals(true)
        return myResult
    }

    // private function to resolve SRV records

    fileprivate func getSRV() {

    }

    // private function to get the AD site

    fileprivate func findSite() {
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
            myLogger.logit(LogLevel.debug, message:"Resetting default naming context to: " + tempDefaultNamingContext)
            defaultNamingContext = tempDefaultNamingContext
            return
        }
        let ldapPingBase64 = getAttributeForSingleRecordFromCleanedLDIF(attribute, ldif: ldifResult)

        if ldapPingBase64 == "" {
            myLogger.logit(LogLevel.base, message: "ldapPingBase64 is empty.")
            myLogger.logit(LogLevel.debug, message:"Resetting default naming context to: " + tempDefaultNamingContext)
            defaultNamingContext = tempDefaultNamingContext
            return
        }

        guard let ldapPing: ADLDAPPing = ADLDAPPing(ldapPingBase64String: ldapPingBase64) else {
             myLogger.logit(LogLevel.debug, message:"Resetting default naming context to: " + tempDefaultNamingContext)
            defaultNamingContext = tempDefaultNamingContext
            return
        }

        // calculate the site

        if defaults.bool(forKey: Preferences.siteIgnore) {
            site = ""
            myLogger.logit(LogLevel.debug, message:"Sites being ignored due to preferences.")
        } else if defaults.string(forKey: Preferences.siteForce) != "" && defaults.string(forKey: Preferences.siteForce) != nil {
            site = defaults.string(forKey: Preferences.siteForce)!
            myLogger.logit(LogLevel.debug, message:"Site being forced to site set in preferences.")
        } else {
            site = ldapPing.clientSite ?? ""
        }


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
        myLogger.logit(LogLevel.debug, message:"Resetting default naming context to: " + tempDefaultNamingContext)
        defaultNamingContext = tempDefaultNamingContext
    }



    fileprivate func cleanLDIF(_ ldif: String) -> [[String:String]] {
        //var myResult = [[String:String]]()

        var ldifLines: [String] = ldif.components(separatedBy: CharacterSet.newlines)

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

            var attribute = ldifLines[lineIndex].characters.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
            if attribute.count == 2 {

                // Get the attribute name (before ;),
                // then add to attributes array if it doesn't exist.
                var attributeName = attribute[0].trim()
                if let index = attributeName.characters.index(of: ";") {
                    attributeName = attributeName.substring(to: index)
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
                    attributeValue = attributeValue.substring(from: attributeValue.characters.index(after: attributeValue.startIndex)).trim()
                } else if attributeValue.hasPrefix(":") {
                    // base64
                    let tempAttributeValue = attributeValue.substring(from: attributeValue.characters.index(after: attributeValue.startIndex)).trim()
                    if (Data(base64Encoded: tempAttributeValue, options: NSData.Base64DecodingOptions.init(rawValue: 0)) != nil) {
                        attributeValue = tempAttributeValue
                    } else {
                        attributeValue = ""
                    }
                }

                // escape double quote
                attributeValue = attributeValue.replacingOccurrences(of: "\"", with: "\"\"")

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

    func getAttributeForSingleRecordFromCleanedLDIF(_ attribute: String, ldif: [[String:String]]) -> String {
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

    func getAttributesForSingleRecordFromCleanedLDIF(_ attributes: [String], ldif: [[String:String]]) -> [String:String] {
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

    func cleanLDAPResultsMultiple(_ result: String, attribute: String) -> String {
        let lines = result.components(separatedBy: "\n")

        var myResult = ""

        for i in lines {
            if (i.contains(attribute)) {
                if myResult == "" {
                    myResult = i.replacingOccurrences( of: attribute + ": ", with: "")
                } else {
                    myResult = myResult + (", " + i.replacingOccurrences( of: attribute + ": ", with: ""))
                }
            }
        }
        return myResult
    }

    // private function that uses netcat to create a socket connection to the LDAP server to see if it's reachable.
    // using ldapsearch for this can take a long time to timeout, this returns much quicker

    fileprivate func testSocket( _ host: String ) -> Bool {

        let mySocketResult = cliTask("/usr/bin/nc -G 5 -z " + host + " " + port)
        if mySocketResult.contains("succeeded!") {
            return true
        } else {
            return false
        }
    }

    // private function to test for an LDAP defaultNamingContext from the LDAP server
    // this tests for LDAP connectivity and gets the default naming context at the same time

    fileprivate func testLDAP ( _ host: String ) -> Bool {

        if defaults.bool(forKey: Preferences.verbose) {
            myLogger.logit(.info, message:"Testing " + host + ".")
        }
        var attribute = "defaultNamingContext"
                
        // if socket test works, then attempt ldapsearch to get default naming context
        
        if defaults.string(forKey: Preferences.lDAPType) == "OD" {
            attribute = "namingContexts"
        }

        swapPrincipals(false)

        var myLDAPResult = ""

        if defaults.bool(forKey: Preferences.ldapAnonymous) {
            myLDAPResult = cliTask("/usr/bin/ldapsearch -N -LLL -x " + maxSSF + "-l 3 -s base -H " + URIPrefix + host + " " + attribute)
        } else {
        myLDAPResult = cliTask("/usr/bin/ldapsearch -N -LLL -Q " + maxSSF + "-l 3 -s base -H " + URIPrefix + host + " " + attribute)
        }

        swapPrincipals(true)

        if myLDAPResult != "" && !myLDAPResult.contains("GSSAPI Error") && !myLDAPResult.contains("Can't contact") {
            let ldifResult = cleanLDIF(myLDAPResult)
            if ( ldifResult.count > 0 ) {
                defaultNamingContext = getAttributeForSingleRecordFromCleanedLDIF(attribute, ldif: ldifResult)
                return true
            }
        }
        return false
    }

    // this checks to see if we can get SRV records for the domain

    fileprivate func checkConnectivity( _ domain: String ) -> Bool {

        self.resolver = DNSResolver.init()

        self.resolver.queryType = "SRV"
        self.resolver.queryValue = "_ldap._tcp." + domain
        if (site != "") {
            self.resolver.queryValue = "_ldap._tcp." + site + "._sites." + domain
        }

        myLogger.logit(.debug, message: "Starting DNS query for LDAP SRV..")

        self.resolver.startQuery()

        while ( !self.resolver.finished ) {
            RunLoop.current.run(mode: RunLoopMode.defaultRunLoopMode, before: Date.distantFuture)
        }
        if (self.resolver.error == nil) {
            myLogger.logit(.debug, message: "Did Receive Query Result: " + self.resolver.queryResults.description)
            //let dnsResults = self.resolver.queryResults as! [[String:AnyObject]]
            currentState = true
            return true
        } else {
            myLogger.logit(.notice, message: "Can't find any SRV records for domain.")
            currentState = false
            return false
        }
    }

    func getSRVRecords(_ domain: String, srv_type: String="_ldap._tcp.") -> [String] {
        self.resolver.queryType = "SRV"

        self.resolver.queryValue = srv_type + domain
        if (site != "" && !srv_type.contains("_kpasswd")) {
            self.resolver.queryValue = srv_type + site + "._sites." + domain
        }
        var results = [String]()

        myLogger.logit(.debug, message: "Starting DNS query for SRV records.")

        self.resolver.startQuery()

        while ( !self.resolver.finished ) {
            RunLoop.current.run(mode: RunLoopMode.defaultRunLoopMode, before: Date.distantFuture)
        }

        if (self.resolver.error == nil) {
            myLogger.logit(.debug, message: "Did Receive Query Result: " + self.resolver.queryResults.description)
            let records = self.resolver.queryResults as! [[String:AnyObject]]
            for record: Dictionary in records {
                let host = record["target"] as! String
                results.append(host)
            }

        } else {
            myLogger.logit(.debug, message: "Query Error: " + self.resolver.error.localizedDescription)
        }
        return results
    }

    // get the list of LDAP servers from a SRV lookup
    // Uses DNSResolver

    func getHosts(_ domain: String ) {

        self.resolver.queryType = "SRV"

        self.resolver.queryValue = "_ldap._tcp." + domain
        if (self.site != "") {
            self.resolver.queryValue = "_ldap._tcp." + self.site + "._sites." + domain
        }

        // check for a query already running

        myLogger.logit(.debug, message: "Starting DNS query for SRV records.")

        self.resolver.startQuery()

        while ( !self.resolver.finished ) {
            RunLoop.current.run(mode: RunLoopMode.defaultRunLoopMode, before: Date.distantFuture)
            myLogger.logit(.debug, message: "Waiting for DNS query to return.")
        }

//        if !self.resolver.finished {
//            myLogger.logit(.debug, message: "DNS query timed out.")
//            self.resolver.stopQuery()
//            self.currentState = false
//            self.hosts.removeAll()
//            return
//        }

        if (self.resolver.error == nil) {
            myLogger.logit(.debug, message: "Did Receive Query Result: " + self.resolver.queryResults.description)

            var newHosts = [LDAPServer]()
            let records = self.resolver.queryResults as! [[String:AnyObject]]
            for record: Dictionary in records {
                let host = record["target"] as! String
                let priority = record["priority"] as! Int
                let weight = record["weight"] as! Int
                // let port = record["port"] as! Int
                let currentServer = LDAPServer(host: host, status: "found", priority: priority, weight: weight, timeStamp: Date())
                newHosts.append(currentServer)
            }

            // now to sort them

            self.hosts = newHosts.sorted { (x, y) -> Bool in
                return ( x.priority <= y.priority )
            }
            self.currentState = true

        } else {
            myLogger.logit(.debug, message: "Query Error: " + self.resolver.error.localizedDescription)
            
            self.currentState = false
            
            print("Hosts known: " + String(describing: self.hosts.count))
            
            if self.hosts.count > 0 {
                print("Keeping previous results, since we are unable to find new LDAP servers.")
                
                // set state to true, since we know at least one semi-valid server
                
                self.currentState = true
                
            } else {
                print("Warning no LDAP servers found from any query.")
            }
            //self.hosts.removeAll()
        }
    }



    // test the list of LDAP servers by iterating through them

    func testHosts() {
        if self.currentState == true {
            for i in 0...( hosts.count - 1) {
                if hosts[i].status != "dead" {
                    myLogger.logit(.info, message:"Trying host: " + hosts[i].host)

                    // socket test first - this could be falsely negative
                    // also note that this needs to return stderr
                    
                    let mySocketResult = cliTask("/usr/bin/nc -G 5 -z " + hosts[i].host + " " + port)
                    
                    if mySocketResult.contains("succeeded!") {
                        
                        var attribute = "defaultNamingContext"
                        
                        // if socket test works, then attempt ldapsearch to get default naming context
                        
                        if defaults.string(forKey: Preferences.lDAPType) == "OD" {
                            attribute = "namingContexts"
                        }
                        
                        swapPrincipals(false)

                        var myLDAPResult = ""

                        if defaults.bool(forKey: Preferences.ldapAnonymous) {
                            myLDAPResult = cliTask("/usr/bin/ldapsearch -N -LLL -x " + maxSSF + "-l 3 -s base -H " + URIPrefix + hosts[i].host + " " + port + " " + attribute)
                        } else {
                            myLDAPResult = cliTask("/usr/bin/ldapsearch -N -LLL -Q " + maxSSF + "-l 3 -s base -H " + URIPrefix + hosts[i].host + " " + port + " " + attribute)
                        }

                        swapPrincipals(true)

                        if myLDAPResult != "" && !myLDAPResult.contains("GSSAPI Error") && !myLDAPResult.contains("Can't contact") {
                            let ldifResult = cleanLDIF(myLDAPResult)
                            if ( ldifResult.count > 0 ) {
                                defaultNamingContext = getAttributeForSingleRecordFromCleanedLDIF(attribute, ldif: ldifResult)
                                hosts[i].status = "live"
                                hosts[i].timeStamp = Date()
                                myLogger.logit(.base, message:"Current LDAP Server is: " + hosts[i].host )
                                myLogger.logit(.base, message:"Current default naming context: " + defaultNamingContext )
                                current = i
                                break
                            }
                        }
                        // We didn't get an actual LDIF Result... so LDAP isn't working.
                        myLogger.logit(.info, message:"Server is dead by way of ldap test: " + hosts[i].host)
                        
                        if defaults.bool(forKey: Preferences.deadLDAPKillTickets) {
                           _ = cliTask("/usr/bin/kdestroy -A")
                        }
                        
                        hosts[i].status = "dead"
                        hosts[i].timeStamp = Date()
                        break
                        
                    } else {
                        myLogger.logit(.info, message:"Server is dead by way of socket test: " + hosts[i].host)
                        hosts[i].status = "dead"
                        hosts[i].timeStamp = Date()
                    }
                }
            }
        }
        
        guard ( hosts.count > 0 ) else {
            return
        }
        
        if hosts.last!.status == "dead" {
            myLogger.logit(.base, message: "All DCs in are dead! You should really fix this.")
            self.currentState = false
        } else {
            self.currentState = true
        }
    }

    func swapPrincipals(_ backToDefault: Bool) {
//        if tickets.defaultPrincipal != tickets.principal {
//        if backToDefault {
//            cliTask("/usr/bin/kswitch -p " + tickets.defaultPrincipal!)
//        } else {
//            cliTask("/usr/bin/kswitch -p " + tickets.principal)
//        }
//    }
    }
    
    // MARK: DNSResolver Delegate Methods
    var resolver: DNSResolver;
    
    func dnsResolver(_ resolver: DNSResolver!, didReceiveQueryResult queryResult: [AnyHashable: Any]!) {
        myLogger.logit(.debug, message: "Did Recieve Query Result: " + queryResult.description);
    }
    
    func dnsResolver(_ resolver: DNSResolver!, didStopQueryWithError error: NSError!) {
        myLogger.logit(.debug, message: "Did Recieve Query Result: " + error.description);
    }

}
