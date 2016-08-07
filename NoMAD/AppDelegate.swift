//
//  AppDelegate.swift
//  NoMAD
//
//  Created by Admin on 7/8/16.
//  Copyright © 2016 Trusource Labs. All rights reserved.
//

import Cocoa
import SystemConfiguration
import Foundation

let notificationKey = NSNotification(name: "updateNow", object: nil)
let notificationCenter = NSNotificationCenter.defaultCenter()
let notificationQueue = NSNotificationQueue.defaultQueue()

@NSApplicationMain

class AppDelegate: NSObject, NSApplicationDelegate, NSUserNotificationCenterDelegate {
    
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        
        NSLog("---- we made it ---")
        
        //NSUserNotificationCenter.defaultUserNotificationCenter().delegate = self
        
        func sendUpdateRequest() {
            
            NSLog("State change, checking things.")
            notificationQueue.enqueueNotification(notificationKey, postingStyle: .PostNow, coalesceMask: .CoalescingOnName, forModes: nil)
        }
        
        let changed: SCDynamicStoreCallBack = {SCDynamicStore,_,_ in
            
            NSLog("State change, checking things.")
            notificationQueue.enqueueNotification(notificationKey, postingStyle: .PostNow, coalesceMask: .CoalescingOnName, forModes: nil)
            
            if  ( defaults.stringForKey("StateChangeAction") != nil ) {
                NSLog("Firing State Change Action")
                cliTask(defaults.stringForKey("StateChangeAction")! + " &")
            }
        }
        
        var dynamicContext = SCDynamicStoreContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        let dcAddress = withUnsafeMutablePointer(&dynamicContext, {UnsafeMutablePointer<SCDynamicStoreContext>($0)})
        
        // set a 15 minute timer to update everything
        
        NSTimer.scheduledTimerWithTimeInterval(900, target: self, selector: #selector(sendUpdateMessage), userInfo: nil, repeats: true)
        
        
        if let dynamicStore = SCDynamicStoreCreate(kCFAllocatorDefault, "io.fti.networkconfigurationchanged", changed, dcAddress){
            
            let keys: [CFStringRef] = ["State:/Network/Global/IPv4"]
            let keyPointer = UnsafeMutablePointer<UnsafePointer<Void>>(keys)
            let keysArray = CFArrayCreate(nil, keyPointer, 1, nil)
            
            SCDynamicStoreSetNotificationKeys(dynamicStore, nil, keysArray)
            
            let loop = SCDynamicStoreCreateRunLoopSource(kCFAllocatorDefault, dynamicStore, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), loop, kCFRunLoopDefaultMode)
            
            
            CFRunLoopRun()
        }
        
        awakeFromNib()
        
    }
    
    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }
    
    func sendUpdateMessage() -> Void {
        NSLog("It's been a while, checking things.")
        notificationQueue.enqueueNotification(notificationKey, postingStyle: .PostNow, coalesceMask: .CoalescingOnName, forModes: nil)
    }
    
}