//
//  Network.swift
//  NoMAD
//
//  Created by Boushy, Phillip on 10/9/16.
//  Copyright © 2016 Trusource Labs. All rights reserved.
//

import Foundation

internal struct Network {
	let ip: String
	let mask: String
	var cidr: Int {
		let maskOctets = mask.componentsSeparatedByString(".")
		var numBits: Int = 0
		for maskOctet in maskOctets {
			numBits += Int( log2(Double(maskOctet)!+1) )
		}
		return numBits
	}
	var networkAddress: String {
		//should create an array of the octets that match up to each x in x.x.x.x
		let octets = ip.componentsSeparatedByString(".")
		let numberNetworkOctets: Int = cidr / 8
		let numberSubnetBits: Int = cidr % 8
		let subnetOctet: Int
		if ( cidr == 32 ) {
			subnetOctet = Int(octets[3])!
		} else {
			subnetOctet = Int(octets[numberNetworkOctets])! - ( Int(octets[numberNetworkOctets])! % Int(pow(Double(2), Double(8 - numberSubnetBits))) )
		}
		let networkAddressValue: String
		switch numberNetworkOctets {
		case 0:
			networkAddressValue = String(subnetOctet) + ".0.0.0"
		case 1:
			networkAddressValue = octets[0] + "." + String(subnetOctet) + ".0.0"
		case 2:
			networkAddressValue = octets[0] + "." + octets[1] + "." + String(subnetOctet) + ".0"
		case 3:
			networkAddressValue = octets[0] + "." + octets[1] + "." + octets[2] + "." + String(subnetOctet)
		default:
			networkAddressValue = octets[0] + "." + octets[1] + "." + octets[2] + "." + octets[3]
		}
		return networkAddressValue
	}
	var cidrNotation: String {
		return networkAddress + "/" + String(cidr)
	}
	var description: String {
		var descriptionValue = "\n== NETWORK INFO ==\n"
		descriptionValue += "IP: \(ip)\n"
		descriptionValue += "Subnet Mask: \(mask)\n"
		descriptionValue += "CIDR: \(cidr)\n"
		descriptionValue += "Network Address: \(networkAddress)\n"
		descriptionValue += "CIDR Notation: \(cidrNotation)\n"
		return descriptionValue
	}
}

//	let searchDomainKeys = SCDynamicStoreCopyKeyList(store, "State:/Network/Service/.*/DNS")! as Array
/*	var i = 0, j = searchDomainKeys.count

while ( i < j ) {

let keyPtr = CFArrayGetValueAtIndex( searchDomainKeys, i )
let key = Unmanaged<CFString>.fromOpaque(COpaquePointer(keyPtr)).takeUnretainedValue()
let value = SCDynamicStoreCopyValue(store, key) as! [String:AnyObject]

if let searchDomains = value["SearchDomains"] as? [String] {
if searchDomains.contains(currentDomain.lowercaseString) {
// get the interface GUID
guard let dnsGUID = searchDomainKeys[i] as? String else { return interfaceName }
let interfaceGUID = dnsGUID.stringByReplacingOccurrencesOfString("DNS", withString: "IPv4")
// look up the service
guard let interfaceList = SCDynamicStoreCopyValue(store, interfaceGUID) as? [String:AnyObject] else { return interfaceName }
interfaceName = interfaceList["InterfaceName"] as? String
break;
}
}
i += 1
}

return interfaceName
*/

/*
private func getListOfPossibleCIDRAddressesForNetwork(network: [String: [String]]) -> Array {
let ipAddress: String = network["IP"]
let subnetMask: String = network["mask"]
var cidrAddresses = [String]()

}
*/
