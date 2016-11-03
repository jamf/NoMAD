//
//  WindowsCATools.swift
//  NoMAD
//
//  Created by Joel Rennich on 5/15/16.
//  Copyright © 2016 Trusource Labs. All rights reserved.
//

import Foundation
import Security

class WindowsCATools {
    
    private var api: String
    var directoryURL: NSURL
    var certCSR: String
    var certTemplate: String
    var myImportError: OSStatus
    
    init(serverURL: String, template: String) {
        self.api = "\(serverURL)/certsrv/"
        
        directoryURL = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString, isDirectory: true)! as NSURL
        do {
            try FileManager.default.createDirectory(at: directoryURL as URL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            myLogger.logit(.info, message: "Can't create temp directory")
        }
        
        // we should return this in case there's an error 
        
        // TODO: Don't use certtool for this, but SecTransform to create the CSR
        cliTask("/usr/bin/certtool r " + directoryURL.appendingPathComponent("new.csr")!.path + " Z")
        
        let path = directoryURL.appendingPathComponent("new.csr")
        
        do {
            certCSR = try NSString(contentsOfFile: path!.path, encoding: String.Encoding.ascii.rawValue) as String
        } catch {
            certCSR = ""
            myLogger.logit(.base, message: "Error getting CSR")
        }
        certTemplate = template
        myImportError = 0
    }
    
    func certEnrollment() -> OSStatus {
        
        // do it all
        // set up the completion handler
        
        let myCompletionHandler: (NSData?, URLResponse?, NSError?) -> Void = { (data, response, error) in
			if (response != nil) {

				let httpResponse = response as! HTTPURLResponse
				
				if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 500) {
				}
			}
			
			if (data != nil ) {

			}
			
			if (error != nil) {
				print(error!)
			}
		}
        
        
        var myReqID = 0
        
		submitCert(certTemplate: certTemplate, completionHandler: { (data, response, error) in
            if (response != nil) {

                let httpResponse = response as! HTTPURLResponse
                
                if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 500) {
                }            }
            
            if (data != nil ) {
                do {
					myReqID = try self.findReqID(data: data!)
				} catch { }
                self.getCert( certID: myReqID, completionHandler: { (data, response, error) in
					if (response != nil) {
						let httpResponse = response as! HTTPURLResponse
						
						if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 500) {
						}            }
					
					if (data != nil ) {
						
						let myCertRef = SecCertificateCreateWithData(nil, data! as CFData)

						let dictionary: [NSString: AnyObject] = [
							kSecClass: kSecClassCertificate,
                            kSecReturnRef : kCFBooleanTrue,
							kSecValueRef: myCertRef!
						];
                        
                        var mySecRef : AnyObject? = nil
						
						self.myImportError = SecItemAdd(dictionary as CFDictionary, &mySecRef)
                        
                        
                        print(mySecRef)
                        
                        print(self.myImportError)
                        
                        var myIdentityRef : SecIdentity? = nil
                        
                        SecIdentityCreateWithCertificate(nil, myCertRef!, &myIdentityRef)
                        /*
                        
                        // update the name of the private key 
                        // first get a reference to the private key from the identity we just imported
                        
                        var myKey : SecKey? = nil
                        
                        self.myImportError = SecIdentityCopyPrivateKey(myIdentityRef!, &myKey)
                        
                        print(self.myImportError)
                        print(myKey)
                        
                        // now get the attributes of the key, create a query dictionary to hold all the attributes first
                        
                        var keychain : SecKeychain? = nil
                        self.myImportError = SecKeychainCopyDefault(&keychain)
                        
                        var info : UnsafeMutablePointer<SecKeychainAttributeInfo>? = nil
                        
                        let keyRefDict = NSArray()
                        let keyArray = keyRefDict.arrayByAddingObject(myKey!)
                        
                        let itemSearchDict: [String:AnyObject] = [
                            kSecClass as String: kSecClassKey,
                            kSecMatchItemList as String : keyArray as! AnyObject,
                            kSecReturnRef as String: true as AnyObject,
                            kSecReturnAttributes as String : true as AnyObject,
                            kSecReturnData as String : true as AnyObject
                        ]
                        
                        var copyReturn : CFTypeRef? = nil
                        
                        self.myImportError = SecItemCopyMatching(itemSearchDict, &copyReturn)
                        
                         print(self.myImportError)
                        print(copyReturn)
                        
                        let itemDeleteDict: [String:AnyObject] = [
                            kSecClass as String: kSecClassKey,
                            kSecMatchItemList as String : keyArray as! AnyObject,
                        ]
                        
                        self.myImportError = SecItemDelete(itemDeleteDict)
                        
                        let myAttrs = copyReturn! as! NSMutableDictionary
                        myAttrs["labl"] = (defaults.stringForKey("userPrincipal")! + "\n"
                        //myAttrs["kSecAttrIsExtractable as String"] = false as AnyObject
                        
                        var keyResult: AnyObject? = nil
                    
                        
                        self.myImportError = SecItemAdd(myAttrs, &keyResult)
                         print(self.myImportError)
                        
                        let itemUpdateDict: [String:AnyObject] = [
                            kSecClass as String: kSecClassKey,
                            kSecMatchItemList as String : keyArray as! AnyObject,
                        ]
                         print(self.myImportError)
                        
                        let attributesToUpdate = NSMutableDictionary()
                        attributesToUpdate["labl"] = defaults.stringForKey("userPrincipal")! as AnyObject?
                        
                        self.myImportError = SecItemUpdate(itemUpdateDict as CFDictionary, attributesToUpdate as CFDictionary)
                        print(SecCopyErrorMessageString(self.myImportError, nil))
                        
                        print(attributesToUpdate)
 */
                        						
                        //myLogger.logit(.base, message: String(self.myImportError))
						
                        //myLogger.logit(.base, message: SecCopyErrorMessageString(self.myImportError, nil) as! String)
					}
					
					if (error != nil) {
						print(error!)
					}
                })
                
            }
            
            if (error != nil) {
                print(error!)
            }
        })
        return self.myImportError
    }
    
    func submitCert(certTemplate: String, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) {

        let request = NSMutableURLRequest(url: (NSURL(string: "\(api)certfnsh.asp"))! as URL)
        request.httpMethod = "POST"
        
        let unreserved = "*-._/"
        let allowed = NSMutableCharacterSet.alphanumeric()
        allowed.addCharacters(in: unreserved)
        
        let encodedCertRequestFinal = certCSR.addingPercentEncoding(withAllowedCharacters: allowed as CharacterSet)
        
        let body = "CertRequest=" + encodedCertRequestFinal! + "&SaveCert=yes&Mode=newreq&CertAttrib=CertificateTemplate:" + certTemplate
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = body.data(using: String.Encoding.utf8)
        
        let session = URLSession.shared
        session.dataTask(with: request as URLRequest, completionHandler: completionHandler).resume()
    }
    
    func findReqID(data: Data) throws -> Int {
        
        let response = String(data: data, encoding: String.Encoding.utf8)
        var myresponse = "0"
        
        if response!.contains("certnew.cer?ReqID=") {
            let responseLines = response?.components(separatedBy: "\n")
            let reqIDRegEx = try NSRegularExpression(pattern: ".*ReqID=", options: NSRegularExpression.Options.caseInsensitive)
            let reqIDRegExEnd = try NSRegularExpression(pattern: "&amp.*", options: NSRegularExpression.Options.caseInsensitive)
            
            for line in responseLines! {
                if line.contains("certnew.cer?ReqID=") {
                    myresponse = reqIDRegEx.stringByReplacingMatches(in: line, options: [], range: NSMakeRange(0, line.characters.count), withTemplate: "")
                    myresponse = reqIDRegExEnd.stringByReplacingMatches(in: myresponse, options: [], range: NSMakeRange(0, myresponse.characters.count), withTemplate: "").replacingOccurrences(of: "\r|", with: "")
                    return Int(myresponse)!
                }
            }
        } else {
            return 0
        }
        return Int(myresponse)!
    }
    
    func getCert(certID: Int, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) {
        
        let request = NSMutableURLRequest(url: (NSURL(string: "\(api)certnew.cer?ReqID=" + String(certID) + "&Enc=bin"))! as URL)
        
        request.httpMethod = "GET"
        
        let session = URLSession.shared
        session.dataTask(with: request as URLRequest, completionHandler: completionHandler).resume()
    }
    
    // TODO: remove the use of certtool and use CommonCrypto instead
    
    // TODO: change the private key label for keys created this way
    
    // TODO: inspect the existing identities for ones matching our AD name, then alert on expiration
    
    // http://opensource.apple.com/source/Security/Security-57337.40.85/SecurityTool/identity_find.c
}
