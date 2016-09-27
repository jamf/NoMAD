//
//  KlistUtil.swift
//  NoMAD
//
//  Created by Joel Rennich on 7/18/16.
//  Copyright © 2016 Trusource Labs. All rights reserved.
//

import Foundation

// Class to parse klist -v --json and return all tickets and times

// TODO: Handle multiple caches at the same time
// TODO: pack everything into one structure

struct Ticket {
    var Issued: NSDate
    var Expires: NSDate
    var Principal: String
}

class KlistUtil {
    
    // defaults

    var allTickets = [Ticket]()
    var principal = ""
    var short = ""
    var cache = ""
    var expire = NSDate()
    var issue = NSDate()
    var dateFormatter = NSDateFormatter()
    var state = true
    var rawTicket: NSData
    var realm = ""
    
    init() {
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        myLogger.logit(3, message: "Getting list of tickets.")
        let rawJSON = cliTask("/usr/bin/klist --json")
        myLogger.logit(3, message: "Raw ticket cache: " + String(rawJSON))
        rawTicket = rawJSON.dataUsingEncoding(NSUTF8StringEncoding)!
        realm = defaults.stringForKey("KerberosRealm") ?? ""
        myLogger.logit(3, message:"Looking for tickets using realm: " + realm )
        if returnAllTickets().containsString("cache") && returnAllTickets().containsString("@" + realm) {
            myLogger.logit(0, message:"Tickets found.")
        } else {
            myLogger.logit(0, message:"No tickets found.")
            state = false
        }
    }
    
    func getTicketJSON() {
        
        realm = defaults.stringForKey("KerberosRealm") ?? ""
        myLogger.logit(3, message:"Looking for tickets using realm: " + realm )
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        let rawJSON = cliTask("/usr/bin/klist --json")
        myLogger.logit(3, message: "Raw ticket cache: " + String(rawJSON))
        rawTicket = rawJSON.dataUsingEncoding(NSUTF8StringEncoding)!
        if returnAllTickets().containsString("cache") {
            if returnAllTickets().containsString("@" + realm ) {
                myLogger.logit(0, message:"Ticket found for domain: " + realm)
                state = true
            } else {
                myLogger.logit(0, message:"No ticket found for domain: " + realm)
                state = false
            }
        } else {
            myLogger.logit(0, message:"No tickets found.")
            state = false
        }
    }
    
    func getCacheListJSON() {
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        let rawJSON = cliTask("/usr/bin/klist -l --json")
        let rawCache = rawJSON.dataUsingEncoding(NSUTF8StringEncoding)!
        if returnAllTickets().containsString("cache") {
            myLogger.logit(0, message:"Tickets found.")
            if returnAllTickets().containsString("@" + defaults.stringForKey("KerberosRealms")!) {
                myLogger.logit(0, message:"Ticket found for domain: " + defaults.stringForKey("KerberosRealms")!)
                state = true
            } else {
                myLogger.logit(0, message:"No ticket found for domain: " + defaults.stringForKey("KerberosRealms")!)
                state = false
            }
        } else {
            myLogger.logit(0, message:"No tickets found.")
            state = false
        }
    }
    
    func getDetails() {
        
        getTicketJSON()
        
        if state {
        
        // clear the previous tickets
        
        allTickets.removeAll()
        
        do {
            let jsonDict = try NSJSONSerialization.JSONObjectWithData(rawTicket, options: .AllowFragments)
            
            // ye haw lets downcast and iterate!
            
            cache = jsonDict["cache"] as! String
            principal = jsonDict["principal"] as! String
            
            short = principal.stringByReplacingOccurrencesOfString("@" + defaults.stringForKey("KerberosRealm")!, withString: "").stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
            state = false
            
            if let tickets = jsonDict["tickets"] as? [[String: AnyObject]] {
                for ticket in tickets {
                    
                    myLogger.logit(3, message: "Looking at ticket: " + String(ticket))
                    
                    if let tick = ticket["Principal"] as? String {
                        let issue = dateFormatter.dateFromString((ticket["Issued"] as? String)!)
                        let expire = dateFormatter.dateFromString((ticket["Expires"] as? String)!)
                        let myTicket = Ticket(Issued: issue!, Expires: expire!, Principal: tick )
                        myLogger.logit(3, message: "Appending ticket: " + String(myTicket))
                        allTickets.append(myTicket)
                        state = true
                    }
                }
            }
        } catch {
            myLogger.logit(3, message: "No tickets found")
            state = false        }
             getExpiration()
    }
    
    func getPrincipal() -> String {
        if state {
            return principal
        } else {
            return "No Ticket"
        }
        }
    }
    
    func getExpiration() {
        if state {
            for ticket in allTickets {
                if ticket.Principal.containsString("krbtgt") {
                    expire = ticket.Expires
                    myLogger.logit(3, message:"Checking for expired tickets.")
                    // we need to check for an expired TGT and set state to false if we are
                    
                    if expire.compare(NSDate()) == NSComparisonResult.OrderedAscending {
                        myLogger.logit(0, message:"Tickets are expired")
                        state = false
                    }
                    break
                }
            }
        } else {
            myLogger.logit(3, message:"No tickets, so no need to look for expired tickets.")
        }
    }
    
    func getIssue() -> NSDate {
        if state {
            for ticket in allTickets {
                if ticket.Principal.containsString("krbtgt") {
                    issue = ticket.Issued
                    return issue
                }
            }
        } else {
            return issue
        }
        return issue
    }
    
    func returnAllTickets() -> String {
        return String(data: rawTicket, encoding: NSUTF8StringEncoding)!
    }
    
    func returnCacheID() -> String {
        return cache
    }
}
