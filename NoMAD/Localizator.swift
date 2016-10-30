//
//  Localizator.swift
//  NoMAD
//
//  Created by Boushy, Phillip on 10/6/16.
//  Copyright © 2016 Trusource Labs. All rights reserved.
//

import Foundation

class Localizator {
	
	static let sharedInstance = Localizator()
	
	lazy var localizableDictionary: NSDictionary! = {
		if let path = Bundle.main.path(forResource: "Languages", ofType: "plist") {
			return NSDictionary(contentsOfFile: path)
		}
		fatalError("Localizable file NOT found")
	}()
	
	func translate(_ string: String) -> String {
		guard let localizedString = (localizableDictionary.value(forKey: string) as AnyObject).value(forKey: "value") as? String else {
			assertionFailure("Missing translation for: \(string)")
			return ""
		}
		return localizedString
	}
}
