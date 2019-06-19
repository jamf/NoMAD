//
//  AppDelegate.swift
//  NoMAD
//
//  Created by Joel Rennich on 7/8/16.
//  Copyright © 2016 Orchard & Grove Inc. All rights reserved.
//

import Cocoa
import SystemConfiguration

/// `Notification` to alert app of changes in system state.
///
/// Listen for this notification if you need to refresh data on network changes.
let updateNotification = Notification(name: Notification.Name(rawValue: "menu.nomad.NoMAD.updateNow"))

@NSApplicationMain

class AppDelegate: NSObject, NSApplicationDelegate {
    
    @objc var refreshTimer: Timer?
    @objc var refreshActivity: NSBackgroundActivityScheduler?
    
    // AppleScript things
    
    @objc var currentADUser : String {
        get {
            return defaults.string(forKey: Preferences.lastUser) ?? "NONE"
        }
    }
    
    @objc var allPrefs : String {
        get {
            return returnAllPrefs()
        }
    }
    
    @objc var currentADUserEmail : String {
        get {
            return defaults.string(forKey: Preferences.userEmail) ?? "NONE"
        }
    }
    
    @objc var currentADDomain : String {
        get {
            return defaults.string(forKey: Preferences.aDDomain) ?? "NONE"
        }
    }
    
    @objc var currentADDomainController : String {
        get {
            return defaults.string(forKey: Preferences.aDDomainController) ?? "NONE"
        }
    }
    
    @objc var currentADSite : String {
        get {
            return defaults.string(forKey: Preferences.aDSite) ?? "NONE"
        }
    }
    
    @objc var signedIn : Bool {
        get {
            return defaults.bool(forKey: Preferences.signedIn)
        }
    }
    
    @objc var currentADUserExpiration : String {
        get {
            if let expiredate = defaults.object(forKey: Preferences.lastPasswordExpireDate) as? Date {
                return expiredate.description(with: Locale.current)
            }
            return "NONE"
        }
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        myLogger.logit(.base, message:"---NoMAD Initialized---")
        let version = String(describing: Bundle.main.infoDictionary!["CFBundleVersionString"]) ?? "NONE"
        let build = String(describing: Bundle.main.infoDictionary!["CFBundleVersion"]!)
        myLogger.logit(.base, message:"NoMAD version: " + version)
        myLogger.logit(.base, message:"NoMAD build: " + build)
        //myLogger.logit(.debug, message: "Current app preferences: \(defaults.dictionaryRepresentation())")

        let changed: SCDynamicStoreCallBack = { dynamicStore, _, _ in
            myLogger.logit(.base, message: "State change, checking things.")
            NotificationQueue.default.enqueue(updateNotification, postingStyle: .now)

            if #available(OSX 10.12, *) {
                Timer.scheduledTimer(withTimeInterval: 5, repeats: false, block: {_ in
                    myLogger.logit(.base, message: "State change, checking things again.")
                    NotificationQueue.default.enqueue(updateNotification, postingStyle: .now)
                })
            } else {
                // wait a few seconds
                let now = Date()
                while abs(now.timeIntervalSinceNow) < 5 {
                    RunLoop.current.run(mode: RunLoopMode.defaultRunLoopMode, before: Date.distantFuture)
                }
                myLogger.logit(.base, message: "State change, checking things again.")
                NotificationQueue.default.enqueue(updateNotification, postingStyle: .now)
            }

            if (defaults.string(forKey: Preferences.stateChangeAction) != "" ) {
                myLogger.logit(.base, message: "Firing State Change Action")
                let _ = cliTask(defaults.string(forKey: Preferences.stateChangeAction)! + " &")
            }
        }

        var dynamicContext = SCDynamicStoreContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        let dcAddress = withUnsafeMutablePointer(to: &dynamicContext, {UnsafeMutablePointer<SCDynamicStoreContext>($0)})

        if let dynamicStore = SCDynamicStoreCreate(kCFAllocatorDefault, "com.trusourcelabs.networknotification" as CFString, changed, dcAddress) {
            let keysArray = ["State:/Network/Global/IPv4" as CFString, "State:/Network/Global/IPv6"] as CFArray
            SCDynamicStoreSetNotificationKeys(dynamicStore, nil, keysArray)
            let loop = SCDynamicStoreCreateRunLoopSource(kCFAllocatorDefault, dynamicStore, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), loop, .defaultMode)
            CFRunLoopRun()
        }

        scheduleTimer()
        awakeFromNib()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        defaults.synchronize()
        refreshActivity?.invalidate()
        refreshTimer?.invalidate()
    }

    @objc func sendUpdateMessage() {
        myLogger.logit(.base, message: "It's been a while, checking things.")
        NotificationQueue.default.enqueue(updateNotification, postingStyle: .now)
    }

    /// Schedule our update notification to fire every 15 minutes or so.
    @objc func scheduleTimer() {
        if #available(OSX 10.12, *) {
            refreshActivity = NSBackgroundActivityScheduler(identifier: "com.trusourcelabs.updatecheck")
            refreshActivity?.repeats = true
            refreshActivity?.interval = 15 * 60
            refreshActivity?.tolerance = 1.5 * 60

            refreshActivity?.schedule() { (completionHandler) in
                self.sendUpdateMessage()
                completionHandler(NSBackgroundActivityScheduler.Result.finished)
            }
        } else {
            refreshTimer = Timer.scheduledTimer(timeInterval: 15 * 60, target: self, selector: #selector(sendUpdateMessage), userInfo: nil, repeats: true)
            refreshTimer?.tolerance = 1.5 * 60
        }
    }
}
