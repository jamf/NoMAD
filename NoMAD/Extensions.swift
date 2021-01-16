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
    
    func variableSwap(_ encoding: Bool=true) -> String {
        
        var cleanString = self
        
        let domain = defaults.string(forKey: Preferences.aDDomain) ?? ""
        let fullName = defaults.string(forKey: Preferences.displayName)?.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? ""
        let serial = getSerial().addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? ""
        let shortName = defaults.string(forKey: Preferences.userShortName) ?? ""
        let upn = defaults.string(forKey: Preferences.userUPN) ?? ""
        let email = defaults.string(forKey: Preferences.userEmail) ?? ""
        let currentDC = defaults.string(forKey: Preferences.aDDomainController) ?? "NONE"
        
        if encoding {
            cleanString = cleanString.replacingOccurrences(of: " ", with: "%20") //cleanString.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlHostAllowed) ?? cleanString
        }
        
        cleanString = cleanString.replacingOccurrences(of: "<<domain>>", with: domain)
        cleanString = cleanString.replacingOccurrences(of: "<<fullname>>", with: fullName)
        cleanString = cleanString.replacingOccurrences(of: "<<serial>>", with: serial)
        cleanString = cleanString.replacingOccurrences(of: "<<shortname>>", with: shortName)
        cleanString = cleanString.replacingOccurrences(of: "<<upn>>", with: upn)
        cleanString = cleanString.replacingOccurrences(of: "<<email>>", with: email)
        cleanString = cleanString.replacingOccurrences(of: "<<noACL>>", with: "")
        cleanString = cleanString.replacingOccurrences(of: "<<domaincontroller>>", with: currentDC)
        
        
        // now to remove any proxy settings
        
        cleanString = cleanString.replacingOccurrences(of: "<<proxy>>", with: "")
        
        return cleanString //.addingPercentEncoding(withAllowedCharacters: .alphanumerics)
        
    }
    
    func isBase64() -> Bool {
        if let data = Data(base64Encoded: self),
           let _ = String(data: data, encoding: .utf8) {
            return true
        }
        return false
    }
    
    func base64String() -> String? {
        if self.isBase64() {
            return self
        } else {
            return self.data(using: .utf8)?.base64EncodedString()
        }
    }
    
    func ldapFilterEscaped() -> String {
        self.replacingOccurrences(of: "\\", with: "\\5c").replacingOccurrences(of: "*", with: "\\2a").replacingOccurrences(of: "(", with: "\\28").replacingOccurrences(of: ")", with: "\\29").replacingOccurrences(of: "/", with: "\\2f")
    }
    
    func encodeNonASCIIAsUTF8Hex() -> String {
        var result = ""
        var startingString = self
        
        if self.isBase64() {
            if let data = Data(base64Encoded: self),
               let decodedString = String(data: data, encoding: .utf8) {
                startingString = decodedString
            }
        }
        
        for character in startingString.ldapFilterEscaped() {
            if character.asciiValue != nil {
                result.append(character)
            } else {
                for byte in String(character).utf8 {
                    result.append("\\" + (NSString(format:"%2X", byte) as String))
                }
            }
        }
        return result
    }
}

extension Character {
    var asciiValue: UInt32? {
        return String(self).unicodeScalars.filter{$0.isASCII}.first?.value
    }
}

extension Data {
    
    init?(fromHexEncodedString string: String) {
        
        // Convert 0 ... 9, a ... f, A ...F to their decimal value,
        // return nil for all other input characters
        func decodeNibble(u: UInt16) -> UInt8? {
            switch(u) {
            case 0x30 ... 0x39:
                return UInt8(u - 0x30)
            case 0x41 ... 0x46:
                return UInt8(u - 0x41 + 10)
            case 0x61 ... 0x66:
                return UInt8(u - 0x61 + 10)
            default:
                return nil
            }
        }
        
        self.init(capacity: string.utf16.count/2)
        var even = true
        var byte: UInt8 = 0
        for c in string.utf16 {
            guard let val = decodeNibble(u: c) else { return nil }
            if even {
                byte = val << 4
            } else {
                byte += val
                self.append(byte)
            }
            even = !even
        }
        guard even else { return nil }
    }
    
    func hexEncodedString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}
