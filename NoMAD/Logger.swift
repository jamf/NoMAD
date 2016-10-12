//
//  Logger.swift
//  NoMAD
//
//  Created by Joel Rennich on 9/6/16.
//  Copyright © 2016 Trusource Labs. All rights reserved.
//

import Foundation

// simple class to handle logging in a semi-sane way
struct LogLevel {
	static let debug = 3
	static let notice = 2
	static let info = 1
	static let base = 0
}


class Logger {
    var loglevel: Int
    
    init() {
        //loglevel = defaults.integerForKey("Verbose")
        loglevel = 3
    }
    
    func logit(level: Int, message: String) {
        if (level <= loglevel) {
            NSLog("level: " + String(level) + " - " + message)
        }
    }
}
