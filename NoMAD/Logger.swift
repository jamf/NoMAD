//
//  Logger.swift
//  NoMAD
//
//  Created by Joel Rennich on 9/6/16.
//  Copyright © 2016 Trusource Labs. All rights reserved.
//

import Foundation

/// The individual logging levels to use when logging in NoMAD
///
/// - base: General errors
/// - info: Positive info
/// - notice: Nice to know issues that may, or may not, cause issues
/// - debug: Lots of verbose logging
enum LogLevel: Int {

    /// General errors
    case base = 0

    /// Positive info
    case info = 1

    /// Nice to know issues that may, or may not, cause issues
    case notice = 2

    /// Lots of verbose logging
    case debug = 3
}


/// Simple class to handle logging levels. Use the `LogLevel` enum to specify the logging details.
class Logger {

    /// Set to a level from `LogLevel` enum to control what gets logged.
    var loglevel: LogLevel

    init() {
        //loglevel = defaults.integerForKey("Verbose")
        //TODO: Set the default logging level to debug currently. Fix this later.
        loglevel = .debug
    }

    /// Simple wrapper around NSLog to provide control of logging.
    ///
    /// - Parameters:
    ///   - level: A value from `LogLevel` enum
    ///   - message: A `String` that describes the information to be logged
    func logit(_ level: LogLevel, message: String) {
        if (level.rawValue <= loglevel.rawValue) {
            NSLog("level: \(level) - " + message)
        }
    }
}
