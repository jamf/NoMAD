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
        
        directoryURL = NSURL(fileURLWithPath: NSTemporaryDirectory()).URLByAppendingPathComponent(NSProcessInfo.processInfo().globallyUniqueString, isDirectory: true)!
        do {
            try NSFileManager.defaultManager().createDirectoryAtURL(directoryURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            myLogger.logit(1, message: "Can't create temp directory")
        }
        
        // we should return this in case there's an error 
        
        // TODO: Don't use certtool for this, but SecTransform to create the CSR
        cliTask("/usr/bin/certtool r " + directoryURL.URLByAppendingPathComponent("new.csr")!.path! + " Z")
        
        let path = directoryURL.URLByAppendingPathComponent("new.csr")
        
        do {
            certCSR = try NSString(contentsOfFile: path!.path!, encoding: NSASCIIStringEncoding) as String
        } catch {
            certCSR = ""
            myLogger.logit(0, message: "Error getting CSR")
        }
        certTemplate = template
        myImportError = 0
    }
    
    func certEnrollment() -> OSStatus {
        
        // do it all
        // set up the completion handler
        
        let myCompletionHandler: (NSData?, NSURLResponse?, NSError?) -> Void = { (data, response, error) in
			if (response != nil) {

				let httpResponse = response as! NSHTTPURLResponse
				
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
        
		submitCert(certTemplate, completionHandler: { (data, response, error) in
            if (response != nil) {

                let httpResponse = response as! NSHTTPURLResponse
                
                if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 500) {
                }            }
            
            if (data != nil ) {
                do {
					myReqID = try self.findReqID(data!)
				} catch { }
                self.getCert( myReqID, completionHandler: { (data, response, error) in
					if (response != nil) {
						let httpResponse = response as! NSHTTPURLResponse
						
						if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 500) {
						}            }
					
					if (data != nil ) {
						
						let myCertRef = SecCertificateCreateWithData(nil, data!)

						let dictionary: [NSString: AnyObject] = [
							kSecClass: kSecClassCertificate,
                            kSecReturnRef : kCFBooleanTrue,
							kSecValueRef: myCertRef!
						];
                        
                        var mySecRef : AnyObject? = nil
						
						self.myImportError = SecItemAdd(dictionary, &mySecRef)
                        
                        
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
                        						
                        //myLogger.logit(0, message: String(self.myImportError))
						
                        //myLogger.logit(0, message: SecCopyErrorMessageString(self.myImportError, nil) as! String)
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
    
    func submitCert( certTemplate: String, completionHandler: (NSData?, NSURLResponse?, NSError?) -> Void) {
        
        let request = NSMutableURLRequest(URL: (NSURL(string: "\(api)certfnsh.asp"))!)
        request.HTTPMethod = "POST"
        
        let unreserved = "*-._/"
        let allowed = NSMutableCharacterSet.alphanumericCharacterSet()
        allowed.addCharactersInString(unreserved)
        
        let encodedCertRequestFinal = certCSR.stringByAddingPercentEncodingWithAllowedCharacters(allowed)
        
        let body = "CertRequest=" + encodedCertRequestFinal! + "&SaveCert=yes&Mode=newreq&CertAttrib=CertificateTemplate:" + certTemplate
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        request.HTTPBody = body.dataUsingEncoding(NSUTF8StringEncoding)
        
        let session = NSURLSession.sharedSession()
        session.dataTaskWithRequest(request, completionHandler: completionHandler).resume()
    }
    
    func findReqID(data: NSData) throws -> Int {
        
        let response = String(data: data, encoding: NSUTF8StringEncoding)
        var myresponse = "0"
        
        if response!.containsString("certnew.cer?ReqID=") {
            let responseLines = response?.componentsSeparatedByString("\n")
            let reqIDRegEx = try NSRegularExpression(pattern: ".*ReqID=", options: NSRegularExpressionOptions.CaseInsensitive)
            let reqIDRegExEnd = try NSRegularExpression(pattern: "&amp.*", options: NSRegularExpressionOptions.CaseInsensitive)
            
            for line in responseLines! {
                if line.containsString("certnew.cer?ReqID=") {
                    myresponse = reqIDRegEx.stringByReplacingMatchesInString(line, options: [], range: NSMakeRange(0, line.characters.count), withTemplate: "")
                    myresponse = reqIDRegExEnd.stringByReplacingMatchesInString(myresponse, options: [], range: NSMakeRange(0, myresponse.characters.count), withTemplate: "").stringByReplacingOccurrencesOfString("\r", withString: "")
                    return Int(myresponse)!
                }
            }
        } else {
            return 0
        }
        return Int(myresponse)!
    }
    
    func getCert(certID: Int, completionHandler: (NSData?, NSURLResponse?, NSError?) -> Void) {
        
        let request = NSMutableURLRequest(URL: (NSURL(string: "\(api)certnew.cer?ReqID=" + String(certID) + "&Enc=bin"))!)
        
        request.HTTPMethod = "GET"
        
        let session = NSURLSession.sharedSession()
        session.dataTaskWithRequest(request, completionHandler: completionHandler).resume()
    }
    
    // TODO: remove the use of certtool and use CommonCrypto instead
    
    // TODO: change the private key label for keys created this way
    
    // TODO: inspect the existing identities for ones matching our AD name, then alert on expiration
    
    // http://opensource.apple.com/source/Security/Security-57337.40.85/SecurityTool/identity_find.c
}
