//  NoMADActionMenu.swift
//  NoMAD
//
//  Created by Joel Rennich on 1/24/18.
//  Copyright © 2018 Orchard & Grove Inc. All rights reserved.
//

import Foundation
import Cocoa

// class to create a menu of all the actions

class NoMADActionMenu : NSObject {
    
    // globals
    
    @objc let menu = NSMenu()
    var actions = [NoMADAction]()
    
    // init
    
    override init() {
        let action1 = NoMADAction()
        action1.text = "action 1"
        let action2 = NoMADAction()
        action2.text = "action 2"
        
        actions.append(action1)
        actions.append(action2)
    }
    
    // create menu
    
    @objc func createMenu() -> NSMenu {
        
        menu.removeAllItems()
        
        for action in actions {
            
            //let itemAction = #selector(action.action)
            
            let menuItem = NSMenuItem()
            menuItem.title = "Boo"
            menuItem.toolTip = "A NoMAD custom action"
            //menuItem.target = action

            menuItem.action = #selector(runAction(_:))
            //menuItem.isEnabled = true
            //menuItem.state = NSControl.StateValue(rawValue: 1)
            print(menuItem)
            menu.addItem(menuItem)
        }
        
        return menu
    }
    
    @IBAction func runAction(_ sender: AnyObject) {
        print("Clicky clicky")
        
    }
    
        override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
            print("validating \(menuItem.title)")
            return true
    }
}
