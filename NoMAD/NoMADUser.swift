//
//  NoMADUser.swift
//  NoMAD
//
//  Created by Boushy, Phillip on 10/12/16.
//  Copyright © 2016 Trusource Labs. All rights reserved.
//

import Foundation
import SystemConfiguration
import SecurityFoundation

enum NoMADUserError: ErrorType {
	case ItemNotFound(String)
	case InvalidParamater(String)
	case InvalidResult(String)
	case UnknownError(String)
}

class NoMADUser {
	
	var userName: String // the username that was used to Sign In
	var realm: String // the realm that NoMAD is connected to.
	
	static let currentConsoleUserName: String = NSUserName()
	static let uid: String = String(getuid())
	private let currentConsoleUserRecord: ODRecord
	
	init?(kerberosPrincipal: String) {
		let kerberosPrincipalArray = kerberosPrincipal.componentsSeparatedByString("@")
		userName = kerberosPrincipalArray[0]
		realm = kerberosPrincipalArray[1]
		guard let unwrappedCurrentConsoleUserRecord = NoMADUser.getCurrentConsoleUserRecord() else {
			return nil
		}
		currentConsoleUserRecord = unwrappedCurrentConsoleUserRecord
		
	}
	
	//Read-Only Functions
	func currentConsoleUserIsADuser() -> Bool {
		if let originalNodeName = try? String(currentConsoleUserRecord.valuesForAttribute(kODAttributeTypeOriginalNodeName)[0]) {
			if ( originalNodeName.contains("/Active Directory")) {
				myLogger.logit(LogLevel.base, message: "Current Console User is an AD user.")
				return originalNodeName.contains("/Active Directory")
			}
		} else {
			myLogger.logit(LogLevel.base, message: "Current Console User is not an AD user.")
			myLogger.logit(LogLevel.notice, message: "Attribute OriginalNodeName does not exist.")
		}
		return false
	}
	
	func checkCurrentConsoleUserPassword(password: String) -> Bool {
		do {
			try currentConsoleUserRecord.verifyPassword(password)
			return true
		} catch let unknownError as NSError {
			myLogger.logit(LogLevel.base, message: "Local User Password is incorrect. Error: " + unknownError.description)
			return false
		}
	}
	
	func checkKeychainPassword(password: String) throws -> Bool {
		var getDefaultKeychain: OSStatus
		var myDefaultKeychain: SecKeychain?
		var err: OSStatus
		
		// get the default keychain path, then attempt to change the password on it
		
		getDefaultKeychain = SecKeychainCopyDefault(&myDefaultKeychain)
		
		if ( getDefaultKeychain == errSecNoDefaultKeychain ) {
			throw NoMADUserError.ItemNotFound("Could not find Default Keychain")
		}
		
		let passwordLength = UInt32(password.characters.count)
		
		err = SecKeychainUnlock(myDefaultKeychain, passwordLength, password, true)
		
		if (err == noErr) {
			return true
		} else if ( err == errSecAuthFailed ) {
			myLogger.logit(LogLevel.base, message: "Authentication failed." + err.description)
			return false
		} else {
			myLogger.logit(LogLevel.base, message: "Unknown error: " + err.description)
			throw NoMADUserError.UnknownError("Unknown error: " + err.description)
		}
		
	}
	
	//Class Functions
	class func getCurrentConsoleUserRecord() -> ODRecord? {
		// Get ODRecords
		let session = ODSession.defaultSession()
		var records = [ODRecord]?()
		do {
			//let node = try ODNode.init(session: session, type: UInt32(kODNodeTypeAuthentication))
			let node = try ODNode.init(session: session, type: UInt32(kODNodeTypeLocalNodes))
			let query = try ODQuery.init(node: node, forRecordTypes: kODRecordTypeUsers, attribute: kODAttributeTypeRecordName, matchType: UInt32(kODMatchEqualTo), queryValues: currentConsoleUserName, returnAttributes: kODAttributeTypeNativeOnly, maximumResults: 0)
			records = try query.resultsAllowingPartial(false) as? [ODRecord]
		} catch {
			myLogger.logit(LogLevel.base, message: "Unable to get local user account ODRecords")
		}
		
		
		// Get the ODRecord that matches the current user's username and UID.
		if ( records != nil ) {
			for case let record in records! {
				let attribute = "dsAttrTypeStandard:UniqueID"
				if let odUid = try? String(record.valuesForAttribute(attribute)[0]) {
					if ( odUid == uid) {
						return record
					}
				}
			}
		}
		return nil
	}
	
	
}
/*
enum PasswordError: ErrorType {
	case ItemNotFound(String)
	case InvalidParamater(String)
	case InvalidODInfo(String)
}

extension ODRecord {
	func isFromAD() -> Bool {
		if let originalNodeName = try? String(self.valuesForAttribute(kODAttributeTypeOriginalNodeName)[0]) {
			return originalNodeName.contains("/Active Directory")
		} else {
			return false
		}
	}
}

// MARK: Read Functions
func checkLocalPassword(currentPassword: String) {

	do {
		let record: ODRecord = try getLocalUserAccountRecord()
		try record.verifyPassword(currentPassword)
	} catch let error as NSError {
		myLogger.logit(LogLevel.base, message: "Error: " + error.description)
	}

}
func checkKeychainPassword(userPrincipal: String, currentPassword: String) {
	
}

// MARK: Write Functions

func changeLocalPassword(kerberosPrincipal: String, oldPassword: String, newPassword1: String, newPassword2: String) {
	do {
		let record: ODRecord = try getLocalUserAccountRecord()
		// OD Attributes
		let attributesFilter = ["dsAttrTypeStandard:AuthenticationAuthority", "samAccountName"]
		let attributesResult = try record.recordDetailsForAttributes(attributesFilter)
		guard let samAccountName = attributesResult["samAccountName"] as? String else {
			throw PasswordError.InvalidODInfo("Unable to get samAccountName")
		}
		guard let authenticationAuthority = attributesResult["dsAttrTypeStandard:AuthenticationAuthority"] as? String else {
			throw PasswordError.InvalidODInfo("Unable to get Authentication Authority")
		}
		
		var username: String = ""
		var realm: String = ""
		// Passed Attributes
		let kerberosPrincipalArray = kerberosPrincipal.componentsSeparatedByString("@")
		if ( kerberosPrincipalArray.count == 2) {
			username = kerberosPrincipalArray[0]
			realm = kerberosPrincipalArray[1]
		} else {
			throw PasswordError.InvalidParamater("Kerberos Principal is invalid. Must be username@REALM")
		}
		
		if samAccountName.lowercaseString == username.lowercaseString && authenticationAuthority.contains(realm) {
			
		}
		
		
	} catch let error as NSError {
		myLogger.logit(LogLevel.base, message: "Error: " + error.description)
	}
	
}
*/
/*
func changeADPassword(kerberosPrincipal: String, oldPassword: String, newPassword1: String, newPassword2: String) -> Bool {
	guard let localAccountRecord = getLocalUserAccountRecord() else {
		myLogger.logit(LogLevel.base, message: "Unable to find Local Account ODRecord, so we don't know if this an actual local account, or an AD mobile account.")
		return false
	}
	if ( localAccountRecord.isFromAD() ) {
		myLogger.logit(LogLevel.info, message: "Local Account is from AD. We'll change the password using OD.")
	
	} else {
		myLogger.logit(LogLevel.info, message: "Local Account is from Local. We'll change the password using KerbUtil.")
		
	}
}
func changeLoginKeychainPassword(oldPassword: String, newPassword1: String, newPassword2: String) {
	
}
func changeKeychainItemPassword(kerberosPrincipal: String, oldPassword: String, newPassword1: String, newPassword2: String) {
	
}

// TODO: create this.
func fixLoginKeychainPassword(oldPassword: String, newPassword1: String, newPassword2: String) {
	
}
*/
//MARK: Helper Functions
/*
func getLocalUserAccountRecord() -> ODRecord? {
	// Get localUserName and UID to find the correct
	/*
	// Get localUserName and UID to find the correct
	let store = SCDynamicStoreCreate(nil, "blah" as CFString, nil, nil)
	var uid: uid_t = 0
	let localUserName = SCDynamicStoreCopyConsoleUser(store, &uid, nil)
	*/
	// Get localUserName and UID to find the correct ODRecord
	let localUserName = NSUserName()
	let uid = String(getuid())
	
	// Get ODRecords
	let session = ODSession.defaultSession()
	var records = [ODRecord]?()
	do {
		//let node = try ODNode.init(session: session, type: UInt32(kODNodeTypeAuthentication))
		let node = try ODNode.init(session: session, type: UInt32(kODNodeTypeLocalNodes))
		let query = try ODQuery.init(node: node, forRecordTypes: kODRecordTypeUsers, attribute: kODAttributeTypeRecordName, matchType: UInt32(kODMatchEqualTo), queryValues: localUserName, returnAttributes: kODAttributeTypeNativeOnly, maximumResults: 0)
		records = try query.resultsAllowingPartial(false) as? [ODRecord]
	} catch {
		myLogger.logit(LogLevel.base, message: "Unable to get local user account ODRecords")
	}
		
	
	// Get the ODRecord that matches the current user's username and UID.
	if ( records != nil ) {
		for case let record in records! {
			let attribute = "dsAttrTypeStandard:UniqueID"
			if let odUid = try? String(record.valuesForAttribute(attribute)[0]) {
				if ( odUid == uid) {
					return record
				}
			}
		}
	}
	return nil
}

extension ODRecord {
	func isFromAD() -> Bool {
		if let originalNodeName = try? String(self.valuesForAttribute(kODAttributeTypeOriginalNodeName)[0]) {
			return originalNodeName.contains("/Active Directory")
		} else {
			return false
		}
	}
}

func localAccountIsAD() -> Bool {
	do {
		let record: ODRecord = try getLocalUserAccountRecord()
		if let originalNodeName = try? record.valuesForAttribute(kODAttributeTypeOriginalNodeName)[0] {
			let originalNodeNameString = String(originalNodeName)
			return originalNodeNameString.contains("/Active Directory")
		}
	} catch let error as NSError {
		myLogger.logit(LogLevel.base, message: "Error: " + error.description)
		
	}
	return false
}
*/

