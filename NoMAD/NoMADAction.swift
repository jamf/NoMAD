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
    
    var showTest: [Dictionary<String, String?>]? = nil
    var title: Dictionary<String, String?>? = nil
    var action : [Dictionary<String, String?>]? = nil
    var post : [Dictionary<String, String?>]? = nil
    
    var preType: String? = nil
    var preTypeOptions: [String]? = nil
    
    var actionType: String? = nil
    var actionTypeOptions: [String]? = nil
    
    // globals
    
    var display : Bool = false
    var text : String = "action item"
    
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
        
        return runActionCommand(action: title!["Command"] as? String ?? "none", options: title!["CommandOptions"] as? String ?? "none")
    }
    
    func preTest() {
        if preType != nil {
            switch preType {
            case "group"? :
                if defaults.array(forKey: Preferences.groups)?.contains(where: { $0 as! String == "admin" }) ?? false {
                    print("group passed")
                }
            default :
                break
            }
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
            
            
        }
    }
    
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        return true
    }
}

