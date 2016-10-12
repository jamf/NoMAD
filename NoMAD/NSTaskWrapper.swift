//
//  NSTaskWrapper.swift
//  NoAD
//
//  Created by Joel Rennich on 3/29/16.
//  Copyright © 2016 Trusource Labs. All rights reserved.
//

// v. 1.4.1

import Foundation
import SystemConfiguration
import IOKit

public func cliTask( command: String, arguments: [String]? = nil) -> String {
	

	var commandLaunchPath: String
	var commandPieces: [String]
	
	if ( arguments == nil ) {
		// turn the command into an array and get the first element as the launch path
		commandPieces = command.componentsSeparatedByString(" ")
		// loop through the components and see if any end in \
		if command.containsString("\\") {
			
			// we need to rebuild the string with the right components
			var x = 0
			
			for line in commandPieces {
				if line.characters.last == "\\" {
					commandPieces[x] = commandPieces[x].stringByReplacingOccurrencesOfString("\\", withString: " ") + commandPieces.removeAtIndex(x+1)
					x -= 1
				}
				x += 1
			}
		}
		commandLaunchPath = commandPieces.removeAtIndex(0)
	} else {
		commandLaunchPath = command
		commandPieces = arguments!
        //myLogger.logit(3, message: commandLaunchPath + " " + arguments!.joinWithSeparator(" "))
	}
	
    // make sure the launch path is the full path -- think we're going down a rabbit hole here
    
    if !commandLaunchPath.containsString("/") {
        let realPath = which(commandLaunchPath)
        commandLaunchPath = realPath
    }
    
    // set up the NSTask instance and an NSPipe for the result
    
    let myTask = NSTask()
    let myPipe = NSPipe()
    let myErrorPipe = NSPipe()
    
    // Setup and Launch!
    
    myTask.launchPath = commandLaunchPath
    myTask.arguments = commandPieces
    myTask.standardOutput = myPipe
    // myTask.standardInput = myInputPipe
    myTask.standardError = myErrorPipe
    
    myTask.launch()
    myTask.waitUntilExit()
    
    let data = myPipe.fileHandleForReading.readDataToEndOfFile()
    let error = myErrorPipe.fileHandleForReading.readDataToEndOfFile()
    let outputError = NSString(data: error, encoding: NSUTF8StringEncoding) as! String
    let output = NSString(data: data, encoding: NSUTF8StringEncoding) as! String
    
    return output + outputError
}

public func cliTaskNoTerm( command: String) -> String {
    
    // This is here because klist -v won't actually trigger the NSTask termination
    
    // turn the command into an array and get the first element as the launch path
    
    var commandPieces = command.componentsSeparatedByString(" ")
    
    // loop through the components and see if any end in \
    
    if command.containsString("\\") {
        
        // we need to rebuild the string with the right components
        var x = 0
        
        for line in commandPieces {
            if line.characters.last == "\\" {
                commandPieces[x] = commandPieces[x].stringByReplacingOccurrencesOfString("\\", withString: " ") + commandPieces.removeAtIndex(x+1)
                x -= 1
            }
            x += 1
        }
    }
    
    var commandLaunchPath = commandPieces.removeAtIndex(0)
    
    // make sure the launch path is the full path -- think we're going down a rabbit hole here
    
    if !commandLaunchPath.containsString("/") {
        let realPath = which(commandLaunchPath)
        commandLaunchPath = realPath
    }
    
    // set up the NSTask instance and an NSPipe for the result
    
    let myTask = NSTask()
    let myPipe = NSPipe()
    let myInputPipe = NSPipe()
    let myErrorPipe = NSPipe()
    
    // Setup and Launch!
    
    myTask.launchPath = commandLaunchPath
    myTask.arguments = commandPieces
    myTask.standardOutput = myPipe
    myTask.standardInput = myInputPipe
    myTask.standardError = myErrorPipe
    
    myTask.launch()
    
    let data = myPipe.fileHandleForReading.readDataToEndOfFile()
    let output = NSString(data: data, encoding: NSUTF8StringEncoding) as! String
    
    return output
}


// this is a quick routine to get the console user

public func getConsoleUser() -> String {
    var uid: uid_t = 0
    var gid: gid_t = 0
    var userName: String = ""
    
    // use SCDynamicStore to find out who the console user is
    
    let theResult = SCDynamicStoreCopyConsoleUser( nil, &uid, &gid)
    userName = theResult! as String
    return userName
}

public func getSerial() -> String {
	
	guard let platformExpert: io_service_t = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice")),
	let platformSerialNumberKey: CFString = kIOPlatformSerialNumberKey else
	{
		return "Unknown"
	}
	
	let serialNumberAsCFString = IORegistryEntryCreateCFProperty(platformExpert, platformSerialNumberKey, kCFAllocatorDefault, 0)
	let serialNumber = serialNumberAsCFString.takeUnretainedValue() as! String
	return serialNumber
	
}

// get hardware MAC addresss

public func getMAC() -> String {
    
    let myMACOutput = cliTask("/sbin/ifconfig -a").componentsSeparatedByString("\n")
    var myMac = ""
    
    for line in myMACOutput {
        if line.containsString("ether") {
            myMac = line.stringByReplacingOccurrencesOfString("ether", withString: "").stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
            break
        }
    }
    return myMac
}

// private function to get the path to the binary if the full path isn't given

private func which(command: String) -> String {
    let task = NSTask()
    task.launchPath = "/usr/bin/which"
    task.arguments = [command]
    
    let whichPipe = NSPipe()
    task.standardOutput = whichPipe
    task.launch()
    
    let data = whichPipe.fileHandleForReading.readDataToEndOfFile()
    let output = NSString(data: data, encoding: NSUTF8StringEncoding) as! String
    
    if output == "" {
        NSLog("Binary doesn't exist")
    }
    
    return output.componentsSeparatedByString("\n").first!
    
}
