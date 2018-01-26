//  NoMADActionMenu.swift
//  NoMAD
//
//  Created by Joel Rennich on 1/24/18.
//  Copyright © 2018 Orchard & Grove Inc. All rights reserved.
//

import Foundation
import Cocoa


let nActionMenu = NoMADActionMenu()
let actionMenuQueue = DispatchQueue(label: "menu.nomad.NoMAD.actions", attributes: [])


// class to create a menu of all the actions

@objc class NoMADActionMenu : NSObject {
    
    // globals
    
    @objc public var actionMenu = NSMenu()
    
    var actions = [NoMADAction]()
    let sharePrefs: UserDefaults? = UserDefaults.init(suiteName: "menu.nomad.actions")
    
    // prefkeys
    
    static let kPrefVersion = "Version"
    static let kPrefActions = "Actions"
    
    // load the actions
    
    func load() {
        
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
            
            // if we already know about it bail
            
            guard let actionName = action["Name"] as? String else { continue }
            
            let newAction = NoMADAction.init(actionName, guid: action["GUID"] as? String ?? nil)
            
            newAction.show = action["Show"] as? [Dictionary<String,String?>] ?? nil
            newAction.action = action["Action"] as? [Dictionary<String,String?>] ?? nil
            newAction.title = action["Title"] as? Dictionary<String,String?> ?? nil
            newAction.post = action["Post"] as? [Dictionary<String,String?>] ?? nil
            newAction.timer = action["Timer"] as? Int ?? nil
            newAction.tip = action["ToolTip"] as? String ?? ""
            
            newAction.connected = action["Connected"] as? Bool ?? false
            
            // add in all options
            
            actions.append(newAction)
        }
    }
    
    @objc func updateActions(_ connected: Bool=false) {
        
        if actions.count < 1 {
            // nothing to update
            return
        }
        
        actionMenuQueue.async(execute: {
            
            for action in self.actions {
                
                if action.connected && !connected {
                    action.display = false
                    continue
                }
                
                if action.timerObject == nil && action.timer != nil {
                    // set up the timer
                    
                    action.timerObject = Timer.init(timeInterval: TimeInterval.init(action.timer! * 60), target: action, selector: #selector(action.runAction), userInfo: nil, repeats: true)
                    RunLoop.main.add(action.timerObject!, forMode: .commonModes)
                }
                
                action.display = action.runCommand(commands: action.show)
                action.text = action.getTitle()
            }
        })
    }
    
    // create menu
    
    @objc func createMenu() {
            
            for action in self.actions {
                
                //let itemAction = #selector(action.action)
                
                
                if action.actionName.lowercased() == "separator" {
                    let separator = NSMenuItem.separator()
                    self.actionMenu.addItem(separator)
                } else {
                    let menuItem = NSMenuItem.init()
                    menuItem.title = action.text
                    
                    if action.status != nil {
                        switch action.status {
                        case "red"? :
                            menuItem.image = NSImage.init(imageLiteralResourceName: NSImage.Name.statusUnavailable.rawValue)
                        case "green"? :
                            menuItem.image = NSImage.init(imageLiteralResourceName: NSImage.Name.statusAvailable.rawValue)
                        case "yellow"? :
                            menuItem.image = NSImage.init(imageLiteralResourceName: NSImage.Name.statusPartiallyAvailable.rawValue)
                        default:
                            break
                        }
                    }
                    
                    if !action.display {
                        menuItem.isHidden = true
                    }
                    
                    menuItem.target = action
                    menuItem.action = #selector(action.runAction)
                    
                    menuItem.isEnabled = true
                    menuItem.toolTip = action.tip
                    menuItem.state = NSControl.StateValue(rawValue: 0)
                    self.actionMenu.addItem(menuItem)
                }
            }
    }
    
    func updateMenu() {
        
        if actionMenu.items.count == 0 {
            return
        }
        
        for i in 0...(actionMenu.items.count - 1 ) {
            actionMenu.items[i].title = actions[i].text
            
            if actions[i].status != nil {
                switch actions[i].status {
                case "red"? :
                    actionMenu.items[i].image = NSImage.init(imageLiteralResourceName: NSImage.Name.statusUnavailable.rawValue)
                case "green"? :
                    actionMenu.items[i].image = NSImage.init(imageLiteralResourceName: NSImage.Name.statusAvailable.rawValue)
                case "yellow"? :
                    actionMenu.items[i].image = NSImage.init(imageLiteralResourceName: NSImage.Name.statusPartiallyAvailable.rawValue)
                default:
                    break
                }
            }
            
            if !actions[i].display {
                actionMenu.items[i].isHidden = true
            } else {
                actionMenu.items[i].isHidden = false
            }
        }
    }
    
    @IBAction func actionClick(_ sender: AnyObject) {
        print("Clicky clicky")
    }
    
    @objc func doeet() {
        print("DOEET")
    }
}
