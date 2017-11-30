//
//  Extensions.swift
//  NoMAD
//
//  Created by Boushy, Phillip on 10/4/16.
//  Copyright © 2016 Orchard & Grove Inc. All rights reserved.
//

import Foundation

extension NSWindow {
    @objc func forceToFrontAndFocus(_ sender: AnyObject?) {
        NSApp.activate(ignoringOtherApps: true)
        self.makeKeyAndOrderFront(sender);
    }
}

extension UserDefaults {
    func sint(forKey defaultName: String) -> Int? {
        
        let defaults = UserDefaults.standard
        let item = defaults.object(forKey: defaultName)
        
        if item == nil {
            return nil
        }
        
        // test to see if it's an Int
        
        if let result = item as? Int {
            return result
        } else {
            // it's a String!
            
            return Int(item as! String)
        }
    }
}

extension String {
    var translate: String {
        return Localizator.sharedInstance.translate(self)
    }
    
    func trim() -> String {
        return self.trimmingCharacters(in: CharacterSet.whitespaces)
    }
    
    func containsIgnoringCase(_ find: String) -> Bool {
        return self.range(of: find, options: NSString.CompareOptions.caseInsensitive) != nil
    }
    
    func safeURLPath() -> String? {
        let allowedCharacters = CharacterSet(bitmapRepresentation: CharacterSet.urlPathAllowed.bitmapRepresentation)
        return addingPercentEncoding(withAllowedCharacters: allowedCharacters)
    }
    
    func safeURLQuery() -> String? {
        let allowedCharacters = CharacterSet(bitmapRepresentation: CharacterSet.urlQueryAllowed.bitmapRepresentation)
        return addingPercentEncoding(withAllowedCharacters: allowedCharacters)
    }

    func safeAddingPercentEncoding(withAllowedCharacters allowedCharacters: CharacterSet) -> String? {
            // using a copy to workaround magic: https://stackoverflow.com/q/44754996/1033581
            let allowedCharacters = CharacterSet(bitmapRepresentation: allowedCharacters.bitmapRepresentation)
            return addingPercentEncoding(withAllowedCharacters: allowedCharacters)
    }
    
    func variableSwap() -> String {
        
        var cleanString = self
        
        let domain = defaults.string(forKey: Preferences.aDDomain) ?? ""
        let fullName = defaults.string(forKey: Preferences.displayName)?.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? ""
        let serial = getSerial().addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? ""
        let shortName = defaults.string(forKey: Preferences.userShortName) ?? ""
        let upn = defaults.string(forKey: Preferences.userUPN) ?? ""
        let email = defaults.string(forKey: Preferences.userEmail) ?? ""
        
        cleanString = cleanString.replacingOccurrences(of: " ", with: "%20") //cleanString.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlHostAllowed) ?? cleanString
        
        cleanString = cleanString.replacingOccurrences(of: "<<domain>>", with: domain)
        cleanString = cleanString.replacingOccurrences(of: "<<fullname>>", with: fullName)
        cleanString = cleanString.replacingOccurrences(of: "<<serial>>", with: serial)
        cleanString = cleanString.replacingOccurrences(of: "<<shortname>>", with: shortName)
        cleanString = cleanString.replacingOccurrences(of: "<<upn>>", with: upn)
        cleanString = cleanString.replacingOccurrences(of: "<<email>>", with: email)
        
        return cleanString //.addingPercentEncoding(withAllowedCharacters: .alphanumerics)
        
    }
    
}
