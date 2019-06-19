//
//  AuthenticationViewController.swift
//  helper
//
//  Created by Joel Rennich on 6/17/19.
//  Copyright © 2019 Joel Rennich. All rights reserved.
//

import Cocoa
import AuthenticationServices
import NoMAD_ADAuth

class AuthenticationViewController: NSViewController {
    @IBOutlet weak var doneButton: NSButton!
    @IBOutlet weak var userField: NSTextField!
    @IBOutlet weak var passField: NSSecureTextField!
    @IBOutlet weak var status: NSTextField!
    @IBOutlet weak var spinner: NSProgressIndicator!
    @IBOutlet weak var logo: NSImageView!
    
    var authorizationRequest: ASAuthorizationProviderExtensionAuthorizationRequest?
    var domain: String?
    var user: String?
    var callingApp: String?
    
    override func loadView() {
        super.loadView()
        // Do any additional setup after loading the view.
        self.status.stringValue = "Please sign in..."
    }
    
    override var nibName: NSNib.Name? {
        return NSNib.Name("AuthenticationViewController")
    }
    
    @IBAction func clickDone(_ sender: Any) {
        
        RunLoop.main.perform {
            self.spinner.startAnimation(nil)
            self.status.stringValue = "Attempting to authenticate"
            let session = NoMADSession.init(domain: "NOMAD.TEST", user: self.userField.stringValue)
            session.userPass = self.passField.stringValue
            session.delegate = self
            session.authenticate()
        }
    }
    
}

extension AuthenticationViewController: ASAuthorizationProviderExtensionAuthorizationRequestHandler {
    
    public func beginAuthorization(with request: ASAuthorizationProviderExtensionAuthorizationRequest) {
        self.authorizationRequest = request
        
        switch request.requestedOperation {
        case "logout":
            klistUtil.kdestroy()
            request.complete()
            return
        default:
            break
        }
        
        callingApp = request.callerBundleIdentifier
        
        if let username = request.extensionData["UserName"] as? String {
            
            let tickets = klistUtil.returnPrincipals()
            
            if tickets.count > 0 {
                for ticket in tickets {
                    if ticket.lowercased() == username.lowercased() {
                        request.complete()
                        return
                    }
                }
            }
            self.userField.stringValue = username
        }
        
        let alert = NSAlert.init()
        alert.messageText = request.authorizationOptions.debugDescription
        alert.runModal()
        
        // Call this to indicate immediate authorization succeeded.
        let authorizationHeaders = [String: String]() // TODO: Fill in appropriate authorization headers.
        
        //request.complete(httpAuthorizationHeaders: authorizationHeaders)
        
        // Or present authorization view and call self.authorizationRequest.complete() later after handling interactive authorization.
        request.presentAuthorizationViewController(completion: { (success, error) in
            if error != nil {
                request.complete(error: error!)
            }
        })
    }
}

extension AuthenticationViewController: NoMADUserSessionDelegate {
    
    func NoMADAuthenticationSucceded() {
        
        NSWorkspace.shared.open(URL.init(string: "nomad://update")!) //DistributedNotificationCenter.default().postNotificationName(NSNotification.Name(rawValue: "menu.nomad.NoMAD.updateNow"), object: nil, userInfo: nil, deliverImmediately: true)
        //NotificationCenter.default.post(name: NSNotification.Name(rawValue: "menu.nomad.NoMAD.updateNow"), object: self)
        spinner.stopAnimation(nil)
        let alert = NSAlert.init()
        alert.messageText = "Success!"
        alert.runModal()
        
        if let callingApp = self.callingApp {
            let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: callingApp)
            runningApps.first?.activate(options: .activateIgnoringOtherApps)
        }
        self.authorizationRequest?.complete()
    }
    
    func NoMADAuthenticationFailed(error: NoMADSessionError, description: String) {
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "menu.nomad.NoMAD.updateNow"), object: self)

        spinner.stopAnimation(nil)
        let alert = NSAlert.init()
        alert.messageText = "Failure: \(description)"
        alert.runModal()
        self.authorizationRequest?.cancel()
    }
    
    func NoMADUserInformation(user: ADUserRecord) {
        spinner.stopAnimation(nil)
        let alert = NSAlert.init()
        alert.messageText = "User Info!"
        alert.runModal()
        self.authorizationRequest?.complete()
    }
}
