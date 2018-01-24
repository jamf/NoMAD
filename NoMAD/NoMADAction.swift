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
    
    // globals
    
    var display : Bool = false
    var text : String = "action item"
    
    // init
    
    override init() {
        
    }
    
    // tests
    
    // determines if you should show the menu or not
    
    func showTest() -> Bool {
        return true
    }
    
    func preTest() {
        
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

