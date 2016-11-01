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
		let maskOctets = mask.components(separatedBy: ".")
		var numBits: Int = 0
		for maskOctet in maskOctets {
			numBits += Int( log2(Double(maskOctet)!+1) )
		}
		return numBits
	}
	var networkAddress: String {
		//should create an array of the octets that match up to each x in x.x.x.x
		let octets = ip.components(separatedBy: ".")
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

// TODO: Remove after verifying new method.
/*
private func getIPandMask() -> [String: [String]] {

var network = [String: [String]]()

// look for interface associated with a search domain of the AD domain
*/
//let searchDomainKeysRaw = SCDynamicStoreCopyKeyList(store, "State:/Network/Service/.*/DNS")
/*let searchDomainKeys: [AnyObject] = searchDomainKeysRaw! as [AnyObject]

for key in searchDomainKeys {
let myValues = SCDynamicStoreCopyValue(store, String(key) as CFString)

if let searchDomain = myValues!["SupplementalMatchDomains"] {
if searchDomain != nil {

let searchDomain2 = myValues!["SupplementalMatchDomains"] as! [String]
if searchDomain2.contains(currentDomain) {
myLogger.logit(2, message: "Using domain-specific interface.")

// get the interface GUID
let interfaceGUID = myValues!["ConfirmedServiceID"]

// look up the service

let interfaceKey = "State:/Network/Service/" + (interfaceGUID!! as! String) + "/IPv4"
let domainInterface = SCDynamicStoreCopyValue(store, interfaceKey as CFString)

// get the local IPs for it

network["IP"] = domainInterface!["Addresses"] as! [String]
network["mask"] = ["255.255.255.254"]
return network
}
}
}
}

myLogger.logit(3, message: "Looking for primary interface.")

let globalInterface = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4")
let interface = globalInterface!["PrimaryInterface"] as! String

myLogger.logit(3, message: "Primary interface is " + interface)

let val = SCDynamicStoreCopyValue(store, "State:/Network/Interface/" + interface + "/IPv4") as! NSDictionary

network["IP"] = (val["Addresses"] as! [String])
guard (( val["SubnetMasks"] ) != nil) else {
network["mask"] = ["255.255.255.254"]
return network
}
network["mask"] = (val["SubnetMasks"] as! [String])
return network
}
*/

// private function to determine subnet mask for site determination
/*
private func countBits(mask: String) -> Int {
var bits: Int
switch mask {
case "255.255.255.255": bits = 32
case "255.255.255.254": bits = 31
case "255.255.255.252": bits = 30
case "255.255.255.248": bits = 29
case "255.255.255.240": bits = 28
case "255.255.255.224": bits = 27
case "255.255.255.192": bits = 26
case "255.255.255.128": bits = 25
case "255.255.255.0"  : bits = 24
case "255.255.254.0"  : bits = 23
case "255.255.252.0"  : bits = 22
case "255.255.248.0"  : bits = 21
case "255.255.240.0"  : bits = 20
case "255.255.224.0"  : bits = 19
case "255.255.192.0"  : bits = 18
case "255.255.128.0"  : bits = 17
case "255.255.0.0"    : bits = 16
case "255.254.0.0"    : bits = 15
case "255.252.0.0"    : bits = 14
case "255.248.0.0"    : bits = 13
case "255.240.0.0"    : bits = 12
case "255.224.0.0"    : bits = 11
case "255.192.0.0"    : bits = 10
case "255.128.0.0"    : bits = 9
case "255.0.0.0"      : bits = 8
case "254.0.0.0"      : bits = 7
case "252.0.0.0"      : bits = 6
case "248.0.0.0"      : bits = 5
case "240.0.0.0"      : bits = 4
case "224.0.0.0"      : bits = 3
case "192.0.0.0"      : bits = 2
case "128.0.0.0"      : bits = 1
case "0.0.0.0"        : bits = 0
default               : bits = 0
}
return bits
}

// private function to convert the mask length to a decimal

private func binToDecimal(mask: Int) -> Int {
var dec: Int
switch mask {
case 0  : dec = 256
case 1  : dec = 128
case 2  : dec = 64
case 3  : dec = 32
case 4  : dec = 16
case 5  : dec = 8
case 6  : dec = 4
case 7  : dec = 2
case 8  : dec = 1
default : dec = 0
}
return dec
}
*/

/*
private func getInterfaceMatchingDomain() -> String? {
	// TODO: Replace cliTask
	// not the best looking code, but it works
	myLogger.logit(2, message: "Trying to get interface with search domain of \(currentServer)")
	let interfaceRaw = cliTask("/sbin/route get " + currentServer )
	
	
	if interfaceRaw.containsString("interface") {
		for line in interfaceRaw.componentsSeparatedByString("\n") {
			if line.containsString("interface") {
				myLogger.logit(3, message: line)
				return line.stringByReplacingOccurrencesOfString("  interface: ", withString: "").stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
			}
		}
	}
	return ""
	
}

// MARK: IP/Subnet Stuff
private func getPrimaryInterface() -> String {
	myLogger.logit(2, message: "Getting the primary interface.")
	let globalInterface = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4")
	let interface = globalInterface!["PrimaryInterface"] as! String
	return interface
}


// private function to get IP and mask
private func getNetworkInfoForInterface( interface:String ) -> Network {
	myLogger.logit(3, message: "Getting network info for interface " + interface)
	
	let val = SCDynamicStoreCopyValue(store, "State:/Network/Interface/" + interface + "/IPv4") as! [String: [String]]
	
	let ip: String = ( val["Addresses"]![0] )
	let mask: String
	if ( val["SubnetMasks"] != nil) {
		mask = val["SubnetMasks"]![0]
	} else {
		mask = "255.255.255.254"
	}
	
	return Network(ip: ip, mask: mask)
}
*/
