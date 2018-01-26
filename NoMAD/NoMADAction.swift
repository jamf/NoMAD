//
//  NoMADAction.swift
//  NoMAD
//
//  Created by Joel Rennich on 1/24/18.
//  Copyright © 2018 Orchard & Grove Inc. All rights reserved.
//

import Foundation


// Class to handle an action

class NoMADAction : NSObject {
    
    // each action needs a name and GUID
    // we'll assign a GUID if one is not present
    
    let actionName : String
    let actionGUID : String
    
    // actions
    
    var show: [Dictionary<String, String?>]? = nil
    var title: Dictionary<String, String?>? = nil
    var action : [Dictionary<String, String?>]? = nil
    var post : [Dictionary<String, String?>]? = nil
    
    // timers and triggers

    var timer : Int? = nil
    var timerObject : Timer? = nil
    var trigger : [String]? = nil
    
    // status
    
    var status: String? = nil
    var visible: Bool = true
    var connected: Bool = false
    
    // globals
    
    var display : Bool = false
    var text : String = "action item"
    var tip : String = ""
    
    // init
    
    init(_ name: String, guid : String?) {
        actionName = name
        if guid == nil {
            actionGUID = UUID().uuidString
        } else {
            actionGUID = guid!
        }
    }
    
    // tests
    
    // determines if you should show the menu or not
    
    func runCommand(commands : [Dictionary<String,String?>]?) -> Bool {
        
        if commands == nil {
            return true
        }
        
        for command in commands! {
            let result = runActionCommand(action: command["Command"] as? String ?? "none" , options: command["CommandOptions"] as? String ?? "none" )
            if result == "false" {
                return false
            }
        }
        return true
    }
    
    func getTitle() -> String {
        
        if title == nil {
            return actionName
        }
        
        let result =  runActionCommand(action: title!["Command"] as? String ?? "none", options: title!["CommandOptions"] as? String ?? "none")
        
        if result == "true" {
            status = "green"
            return actionName
        } else if result == "false" {
            status = "red"
            return actionName
        } else {
            return result
        }
    }
    
    func displayItem() -> String {
        return text
    }
    
    @IBAction func runAction(_ sender: AnyObject) {
        let result = runCommand(commands: action)
        
        if result {
            myLogger.logit(.base, message: "Action succeeded: \(actionName)")
        } else {
            myLogger.logit(.base, message: "Action failed: \(actionName)")
        }
        
        if post != nil {
            // run any post commands
            // TODO: add in a way to report on result of Action

            _ = runCommand(commands: post)
        }
    }
    
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        return true
    }
}

