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
    var Issued: Date
    var Expires: Date
    var Principal: String
}

class KlistUtil {

    // defaults

    var allTickets = [Ticket]()
    var principal = ""
    var short = ""
    var cache = ""
    var expire = Date()
    var issue = Date()
    var dateFormatter = DateFormatter()
    var state = true
    var rawTicket: Data = Data()
    var realm = ""
    var rawJSON = ""
    var defaultPrincipal = ""

    init() {
        dateFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        realm = defaults.string(forKey: "KerberosRealm") ?? ""
    }

    func getTicketJSON() {

        realm = defaults.string(forKey: "KerberosRealm") ?? ""
        myLogger.logit(.debug, message:"Looking for tickets using realm: " + realm )
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        rawJSON = cliTask("/usr/bin/klist -l --json")
        rawJSON = rawJSON.replacingOccurrences(of: "\\ ", with: " ")
        myLogger.logit(.debug, message: "Raw ticket cache: " + String(rawJSON))
        rawTicket = rawJSON.data(using: String.Encoding.utf8)!
        if returnAllTickets().contains("Cache") {
            if returnAllTickets().contains("@" + realm ) {
                myLogger.logit(.base, message:"Ticket found for domain: " + realm)
                state = true
            } else {
                myLogger.logit(.base, message:"No ticket found for domain: " + realm)
                state = false
            }
        } else {
            myLogger.logit(.base, message:"No tickets found.")
            state = false
        }
    }

    func getCacheListJSON() {
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        var rawJSON = cliTask("/usr/bin/klist -l --json")

        rawJSON = rawJSON.replacingOccurrences(of: "\\ ", with: " ")

        let rawCache = rawJSON.data(using: String.Encoding.utf8)!
        if returnAllTickets().contains("Cache") {
            myLogger.logit(.base, message:"Tickets found.")
            if returnAllTickets().contains("@" + defaults.string(forKey: "KerberosRealm")!) {
                myLogger.logit(.base, message:"Ticket found for domain: " + defaults.string(forKey: "KerberosRealm")!)
                state = true
            } else {
                myLogger.logit(.base, message:"No ticket found for domain: " + defaults.string(forKey: "KerberosRealm")!)
                state = false
            }
        } else {
            myLogger.logit(.base, message:"No tickets found.")
            state = false
        }
    }

    func getDetails() {

        getTicketJSON()

        if state {

            // clear the previous tickets

            allTickets.removeAll()

            do {
                let ticketCache = try! JSONSerialization.jsonObject(with: rawTicket, options: .mutableLeaves)
                print(ticketCache)
                var jsonTicket: AnyObject

                // need to find out if we have more than one ticket cache

                for  object in ticketCache as! Array<Any> {
                    let dict = object as! Dictionary<String, Any>

                    // check for default

                    if ( dict["Default Cache"]! as! String ) == "yes" {
                        defaultPrincipal = dict["Name"]! as! String
                        myLogger.logit(.debug, message: "Default principal is " + defaultPrincipal)
                    }

                    let singleTicket = cliTask("/usr/bin/klist --json -c " + (dict["Cache name"]! as! String) )

                    // breaks here on names with spaces

                    let jsonDict = try! JSONSerialization.jsonObject(with: singleTicket.data(using: String.Encoding.utf8)!, options: .mutableLeaves) as? [String: AnyObject]

                    // check if we have a ticket for the right realm

                    if (jsonDict?["principal"] as! String).contains("@" + defaults.string(forKey: "KerberosRealm")!) {

                        // ye haw lets downcast and iterate!

                        cache = jsonDict?["cache"] as! String
                        principal = jsonDict?["principal"] as! String
                        short = principal.replacingOccurrences(of: "@" + defaults.string(forKey: "KerberosRealm")!, with: "").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                        state = false

                        if let tickets = jsonDict?["tickets"] as? [[String: AnyObject]] {
                            for ticket in tickets {
                                myLogger.logit(.debug, message: "Looking at ticket: " + String(describing: ticket))

                                if let tick = ticket["Principal"] as? String {
                                    print(ticket)
                                    let issue = dateFormatter.date(from: (ticket["Issued"] as? String)!)
                                    let expire = dateFormatter.date(from: (ticket["Expires"] as? String)!)
                                    let myTicket = Ticket(Issued: issue!, Expires: expire!, Principal: tick )
                                    myLogger.logit(.debug, message: "Appending ticket: " + String(describing: myTicket))
                                    allTickets.append(myTicket)
                                    state = true
                                }
                            }
                        }
                    }
                }
            }
            getExpiration()

            // write out if we have tickets

            defaults.set(state, forKey: Preferences.signedIn)
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
                if ticket.Principal.contains("krbtgt") {
                    expire = ticket.Expires
                    myLogger.logit(.debug, message:"Checking for expired tickets.")
                    // we need to check for an expired TGT and set state to false if we are

                    if expire.compare(Date()) == ComparisonResult.orderedAscending {
                        myLogger.logit(.base, message:"Tickets are expired")
                        state = false
                    }
                    break
                }
            }
        } else {
            myLogger.logit(.debug, message:"No tickets, so no need to look for expired tickets.")
        }
    }

    func getIssue() -> Date {
        if state {
            for ticket in allTickets {
                if ticket.Principal.contains("krbtgt") {
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
        return String(data: rawTicket, encoding: String.Encoding.utf8)!
    }
    
    func returnCacheID() -> String {
        return cache
    }
}
