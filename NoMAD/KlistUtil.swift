//
//  KlistUtil.swift
//  NoMAD
//
//  Created by Admin on 7/18/16.
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
    var cache = ""
    var expire = NSDate()
    var issue = NSDate()
    var dateFormatter = NSDateFormatter()
    var state = true
    var rawTicket: NSData
    
    init() {
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        let rawJSON = cliTask("/usr/bin/klist --json")
        rawTicket = rawJSON.dataUsingEncoding(NSUTF8StringEncoding)!
        if returnAllTickets().containsString("cache") {
            NSLog("Tickets found.")
        } else {
            NSLog("No tickets found.")
            state = false
        }
    }
    
    func getTicketJSON() {
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        let rawJSON = cliTask("/usr/bin/klist --json")
        rawTicket = rawJSON.dataUsingEncoding(NSUTF8StringEncoding)!
        if returnAllTickets().containsString("cache") {
            NSLog("Tickets found.")
        } else {
            NSLog("No tickets found.")
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
            
            if let tickets = jsonDict["tickets"] as? [[String: AnyObject]] {
                for ticket in tickets {
                    if let tick = ticket["Principal"] as? String {
                        let issue = dateFormatter.dateFromString((ticket["Issued"] as? String)!)
                        let expire = dateFormatter.dateFromString((ticket["Expires"] as? String)!)
                        let myTicket = Ticket(Issued: issue!, Expires: expire!, Principal: tick )
                        allTickets.append(myTicket)
                    }
                }
            }
        } catch {
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
                    break
                }
            }
        } else {
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