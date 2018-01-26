//  NoMADActionMenu.swift
//  NoMAD
//
//  Created by Joel Rennich on 1/24/18.
//  Copyright © 2018 Orchard & Grove Inc. All rights reserved.
//

import Foundation
import Cocoa


let nActionMenu = NoMADActionMenu()

// class to create a menu of all the actions

@objc class NoMADActionMenu : NSObject {
    
    // globals
    
    @objc public let actionMenu = NSMenu()
    
    var actions = [NoMADAction]()
    let sharePrefs: UserDefaults? = UserDefaults.init(suiteName: "menu.nomad.actions")
    
    // prefkeys
    
    static let kPrefVersion = "Version"
    static let kPrefActions = "Actions"
    
    // update actions
    
    func update() {
        
        // read in the preferences
        
        if sharePrefs?.integer(forKey: NoMADActionMenu.kPrefVersion) ?? 0 != 1 {
            // wrong version
            return
        }
        
        guard let rawPrefs = sharePrefs?.array(forKey: NoMADActionMenu.kPrefActions) as? [Dictionary<String, AnyObject?>] else { return }
        
        // if no shares we bail
        
        if rawPrefs.count < 1 {
            return
        }
        
        // loop through the shares
        
        for action in rawPrefs {
            
            guard let actionName = action["Name"] as? String else { continue }
            
            let newAction = NoMADAction.init(actionName, guid: action["GUID"] as? String ?? nil)
            
            newAction.showTest = action["ShowTest"] as? [Dictionary<String,String?>] ?? nil
            newAction.action = action["Action"] as? [Dictionary<String,String?>] ?? nil
            newAction.title = action["Title"] as? Dictionary<String,String?> ?? nil
            
            // add in all options
            
            actions.append(newAction)
        }
    }
    
    // create menu
    
    @objc func createMenu() {
        
        actionMenu.removeAllItems()
        
        for action in actions {
            
            //let itemAction = #selector(action.action)
            
            if !action.runCommand(commands: action.showTest) {
                continue
            }
            
            if action.actionName.lowercased() == "separator" {
                let separator = NSMenuItem.separator()
                actionMenu.addItem(separator)
            } else {
            let menuItem = NSMenuItem.init()
            menuItem.title = action.getTitle()
            menuItem.target = action
            menuItem.action = #selector(action.runAction)

            menuItem.isEnabled = true
            menuItem.toolTip = "A NoMAD custom action"
            menuItem.state = NSControl.StateValue(rawValue: 0)
            actionMenu.addItem(menuItem)
            }
        }
        //print(actionMenu)
        //actionMenu.autoenablesItems = false
       // return actionMenu
    }
    
    @IBAction func actionClick(_ sender: AnyObject) {
        print("Clicky clicky")
    }
    
    @objc func doeet() {
        print("DOEET")
    }
}
