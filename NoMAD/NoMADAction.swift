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
    
    var showType: String? = nil
    var showTypeOptions: String? = nil
    
    var preType: String? = nil
    var preTypeOptions: String? = nil
    
    var actionType: String? = nil
    var actionTypeOptions: String? = nil
    
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
    
    func showTest() -> Bool {
        return true
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
    
    @IBAction func action(_ sender: AnyObject) {
        print("action \(text) done")
    }
    
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        print("********")
        return true
    }
    
    func post() {
        
    }
}

