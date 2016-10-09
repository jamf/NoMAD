//
//  ADNetlogon.swift
//  NoMAD
//
//  Created by Boushy, Phillip on 10/8/16.
//  Copyright © 2016 Trusource Labs. All rights reserved.
//

import Foundation

class ADNetlogon {
	var netlogonData: String //buffer
	var type: Int //uint32
	var flags: Int //uint32
	var forest: String //rfc1035
	var domain: String //rfc1035
	var hostname: String //rfc1035
	var netbiosDomain: String //rfc1035
	var netbiosHostname: String //rfc1035
	var user: String //rfc1035
	var clientSite: String //rfc1035
	var serverSite: String
	
	
	init( netlogonBase64String: String ) {
		//netlogonData = NSData(base64EncodedString: netlogonBase64String, options: NSDataBase64DecodingOptions(rawValue: 0))
		netlogonData = ""
		type = 0
		flags = 0
		forest = ""
		domain = ""
		hostname = ""
		netbiosDomain = ""
		netbiosHostname = ""
		user = ""
		clientSite = ""
		serverSite = ""
	}
	
	func decodeUint32() -> Int {
		var value: Int = 0
		
		return value
	}
	
	func decodeRFC1035() -> String {
		var result: String = ""
		
		return result
	}
	
	func readByte( offset: Int? ) {
		if (offset == nil) {
			
		}
	
	}
}
