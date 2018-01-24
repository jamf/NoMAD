//  NoMADActionMenu.swift
//  NoMAD
//
//  Created by Joel Rennich on 1/24/18.
//  Copyright © 2018 Orchard & Grove Inc. All rights reserved.
//

import Foundation
import Cocoa

// class to create a menu of all the actions

@objc class NoMADActionMenu : NSObject {
    
    // globals
    
    @objc let menu = NSMenu()
    var actions = [NoMADAction]()
    let sharePrefs: UserDefaults? = UserDefaults.init(suiteName: "menu.nomad.actions")
    
    // prefkeys
    
    static let kPrefVersion = "Version"
    static let kPrefActions = "Actions"

    // init
    
    override init() {
        
        // pull in all actions from a pref file
        
    }
    
    // update actions
    
    func update() {
        
        // read in the preferences
        
        if sharePrefs?.integer(forKey: NoMADActionMenu.kPrefVersion) ?? 0 != 1 {
            // wrong version
            return
        }
        
        guard let rawPrefs = sharePrefs?.array(forKey: NoMADActionMenu.kPrefActions) as? [Dictionary<String, AnyObject?>] else { return }
        
        // if no shares we bail
        
        if rawPrefs.count ?? 0 < 1 {
            return
        }
        
        // loop through the shares
        
        for action in rawPrefs {
            
            guard let actionName = action["Name"] as? String else { continue }
            
            let newAction = NoMADAction.init(actionName, guid: action["GUID"] as? String ?? nil)
            actions.append(newAction)
        }
    }
    
    // create menu
    
    @objc func createMenu() -> NSMenu {
        
        menu.removeAllItems()
        
        for action in actions {
            
            //let itemAction = #selector(action.action)
            
            let menuItem = NSMenuItem()
            menuItem.title = action.actionName
            menuItem.isEnabled = true

            menuItem.toolTip = "A NoMAD custom action"
            menuItem.action = #selector(runAction)
            menuItem.target = self
            
            //menuItem.state = NSControl.StateValue(rawValue: 1)
            
            print(menuItem)
            menu.addItem(menuItem)
        }
        
        return menu
    }
    
    @objc func runAction() {
        print("Clicky clicky")
        
    }
}
