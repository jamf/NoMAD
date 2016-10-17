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
	/**
	Lots and lots and lots of details.
	*/
	static let debug = 3
	/**
	Nice to know
	*/
	static let notice = 2
	/**
	Positive info
	*/
	static let info = 1
	/**
	Errors
	*/
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
