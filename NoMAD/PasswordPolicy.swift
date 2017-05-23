//
//  PasswordPolicy.swift
//  NoMAD Pro
//
//  Created by Joel Rennich on 5/5/17.
//  Copyright © 2017 NoMAD. All rights reserved.
//

import Foundation

// password policy

private let caps: Set<Character> = Set("ABCDEFGHIJKLKMNOPQRSTUVWXYZ".characters)
private let lowers: Set<Character> = Set("abcdefghijklmnopqrstuvwxyz".characters)
private let numbers: Set<Character> = Set("1234567890".characters)
private let symbols: Set<Character> = Set("!\"@#$%^&*()_-+={}[]|:;<>,.?~`\\/".characters)
private var passwordPolicy = [String : AnyObject ]()

private var minLength: String = "0"
private var minUpperCase: String = "0"
private var minLowerCase: String = "0"
private var minNumber: String = "0"
private var minSymbol: String = "0"
private var minMatches: String = "0"

struct complexityPolicy {
    var minLength: Int
    var minUpperCase: Int
    var minLowerCase: Int
    var minNumber: Int
    var minSymbol: Int
    var minMatches: Int
    var excludeUsername: Bool
}

class PasswordPolicy {

    var policyObject = complexityPolicy(minLength: 0, minUpperCase: 0, minLowerCase: 0, minNumber: 0, minSymbol: 0, minMatches: 0, excludeUsername: false)

    init(policy: [AnyHashable: Any]? ) {

        for item in policy! {
            switch item.key as! String {
            case "minLength" :
                policyObject.minLength = item.value as! Int
            case "minUpperCase" :
                policyObject.minUpperCase = item.value as! Int
            case "minLowerCase" :
                policyObject.minLowerCase = item.value as! Int
            case "minNumber" :
                policyObject.minNumber = item.value as! Int
            case "minSymbol" :
                policyObject.minSymbol = item.value as! Int
            case "minMatches" :
                policyObject.minMatches = item.value as! Int
            case "excludeUsername" :
                policyObject.excludeUsername = item.value as! Bool
            default:
                myLogger.logit(.debug, message: "Unable to set password policy: \(item.key)")
            }
        }
    }

    // safety functions

    func checkPolicy() {

    }

    func checkPassword(pass: String, username: String="") -> String {

        var result = ""

        let capsOnly = String(pass.characters.filter({ (caps.contains($0))}))
        let lowerOnly = String(pass.characters.filter({ (lowers.contains($0))}))
        let numberOnly = String(pass.characters.filter({ (numbers.contains($0))}))
        let symbolOnly = String(pass.characters.filter({ (symbols.contains($0))}))

        var totalMatches = 0

        if pass.characters.count < policyObject.minLength {
            result.append("Length requirement not met.\n")
        }

        if capsOnly.characters.count < policyObject.minUpperCase {
            result.append("Upper case character requirement not met.\n")
        } else {
            totalMatches += 1
        }

        if lowerOnly.characters.count < policyObject.minLowerCase {
            result.append("Lower case character requirement not met.\n")
        } else {
            totalMatches += 1
        }

        if numberOnly.characters.count < policyObject.minNumber {
            result.append("Numeric character requirement not met.\n")
        } else {
            totalMatches += 1
        }

        if symbolOnly.characters.count < policyObject.minSymbol {
            result.append("Symbolic character requirement not met.\n")
        } else {
            totalMatches += 1
        }

        if totalMatches >= policyObject.minMatches && policyObject.minMatches != 0 && pass.characters.count >= policyObject.minLength {
            result = ""
        }

        if policyObject.excludeUsername && pass.contains(username) {
            result.append("Password can not contain user name.")
        }

        return result
    }


}
