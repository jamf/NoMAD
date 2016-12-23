//
//  NoMADTests.swift
//  NoMADTests
//
//  Created by Bitson on 8/3/16.
//  Copyright © 2016 Trusource Labs. All rights reserved.
//

import XCTest

@testable import NoMAD

class NoMADTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
	
	func testNetworkStruct() {
		let slash8 = Network(ip: "10.2.3.5", mask: "255.0.0.0")
		XCTAssertEqual(slash8.cidrNotation, "10.0.0.0/8", "slash8 cidrNotation is incorrect.")
		
		let slash16 = Network(ip: "172.16.13.5", mask: "255.255.0.0")
		XCTAssertEqual(slash16.cidrNotation, "172.16.0.0/16", "slash16 cidrNotation is incorrect.")
		
		let slash24 = Network(ip: "192.168.0.1", mask: "255.255.255.0")
		XCTAssertEqual(slash24.cidrNotation, "192.168.0.0/24", "slash24 cidrNotation is incorrect.")
		
		let slash32 = Network(ip: "12.37.35.23", mask: "255.255.255.255")
		XCTAssertEqual(slash32.cidrNotation, "12.37.35.23/32", "slash32 cidrNotation is incorrect.")
	}
    
}

