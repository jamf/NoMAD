//
//  Localizator.swift
//  NoMAD
//
//  Created by Boushy, Phillip on 10/6/16.
//  Copyright © 2016 Orchard & Grove Inc. All rights reserved.
//

import Foundation

class Localizator : NSObject {

    static let sharedInstance = Localizator()

    lazy var localizableDictionary: [String:AnyObject] = {
        if let path = Bundle.main.path(forResource: "Languages", ofType: "plist") {
            return NSDictionary(contentsOfFile: path) as! [String : AnyObject]
        }
        fatalError("Localizable file NOT found")
    }()

    func translate(_ string: String) -> String {
        guard let localizedString = localizableDictionary[string]?["value"] else {
            assertionFailure("Missing translation for: \(string)")
            return ""
        }
        return localizedString as! String
    }
}
