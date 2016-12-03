//
//  SelfServiceManager.swift
//  NoMAD
//
//  Created by Tom Nook on 11/29/16.
//  Copyright © 2016 Trusource Labs. All rights reserved.
//

import Foundation


/// The software self-service apps that NoMAD can discover.
///
/// - casper: JAMF Software
/// - lanrev: HEAT Software
/// - munki: OpenSource Software
enum SelfServiceType {
    case casper
    case lanrev
    case munki
}

class SelfServiceManager {

    /// Checks for several Mac client management agents
    ///
    /// - Returns: A value from `SelfServiceType` enum or nil.
    func discoverSelfService() -> SelfServiceType? {

        let selfServiceFileManager = FileManager.default

        if selfServiceFileManager.fileExists(atPath: "/Applications/Self Service.app") {
            myLogger.logit(.info, message:"Using Casper for Self Service")
            return .casper
        }
        if selfServiceFileManager.fileExists(atPath: "/Library/Application Support/LANrev Agent/LANrev Agent.app/Contents/MacOS/LANrev Agent") {
            myLogger.logit(.info, message:"Using LANRev for Self Service")
            return .lanrev
        }
        if selfServiceFileManager.fileExists(atPath: "/Applications/Managed Software Center.app") {
            myLogger.logit(.info, message:"Using Munki for Self Service")
            return .munki
        }
        return nil
       }
    }
