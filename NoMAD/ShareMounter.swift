//
//  ShareMounter.swift
//  NoMAD
//
//  Created by Joel  on 8/29/16.
//  Copyright © 2016 Orchard & Grove Inc. All rights reserved.
//

// mad props to Kyle Crawshaw
// since much of this is cribbed from Share Mounter

import Cocoa
import Foundation
import NetFS
import CoreServices

enum mountStatus {
    case unmounted, toBeMounted, notInGroup, mounting, mounted, errorOnMount
}

enum shareKeys {
    static let homeMount = "HomeMount"
    static let mount = "Mount"
    static let shares = "Shares"
    static let groups = "Groups"
    static let connectedOnly = "ConnectedOnly"
    static let options = "Options"
    static let name = "Name"
    static let autoMount = "AutoMount"
    static let localMount = "LocalMount"
    static let url = "URL"
    static let userShares = "UserShares"
}

struct share_info {
    var groups: [String]
    var url: URL
    var name: String
    var options: [String]
    var connectedOnly: Bool
    var mountStatus: mountStatus?
    var localMount: String?
    var autoMount: Bool
    var reqID: AsyncRequestID?
    var attemptDate: Date?
    var localMountPoints: String?
}

struct mounting_shares_info {
    var share_url: URL
    var reqID: AsyncRequestID?
    var mount_time: Date
}

class ShareMounter: NSArrayController {
    var sharePrefs: UserDefaults? = UserDefaults.init(suiteName: "menu.nomad.shares")
    var all_shares = [share_info]()
    let ws = NSWorkspace.init()
    //var prefs: [String]
    lazy var userPrincipal: String = ""
    var mountedShares = [URL]()
    var knownShares = [URL]()
    lazy var shareCount = 0
    lazy var myGroups = [String]()
    lazy var mountHome: Bool = false
    lazy var all_mounting_shares = [mounting_shares_info]()
    var connectedState: Bool = false
    
    var mountedSharePaths = [URL:String]()
    
    func windowShouldClose(_ sender: Any) -> Bool {
        return true
    }
    
    
    // Utility functions
    
    func getMounts() {
        
        //knownShares = mountedShares
        
        // clear all the known shares
        
        //all_shares.removeAll()
        
        // check for home mount
        
        let homeDict = sharePrefs?.dictionary(forKey: shareKeys.homeMount)
        
        if homeDict != nil {
            // adding the home mount to the shares
            myLogger.logit(.debug, message: "Evaluating home share for automounts.")
            var currentShare = share_info(groups: homeDict?[shareKeys.groups] as! [String], url: URL(string: "smb:" + (defaults.string(forKey: Preferences.userHome))!)!, name: defaults.string(forKey: Preferences.menuHomeDirectory) ?? "HomeSharepoint".translate, options: homeDict?[shareKeys.options] as! [String], connectedOnly: true, mountStatus: mountStatus.toBeMounted, localMount: nil, autoMount: (homeDict?["Mount"]) as! Bool, reqID: nil, attemptDate: nil, localMountPoints: nil)
            
            if mountedShares.contains(currentShare.url) {
                //currentShare.mountStatus = .mounted
            }
            
            if !knownShares.contains(URL(string: "smb:" + (defaults.string(forKey: Preferences.userHome))!)!) {
                self.all_shares.append(currentShare)
                knownShares.append(URL(string: "smb:" + (defaults.string(forKey: Preferences.userHome))!)!)
            }
        } else {
            myLogger.logit(.debug, message: "No Home mount dictionary.")
        }
        
        if let mountsRaw = (sharePrefs?.array(forKey: shareKeys.shares)) {
            //let userMounts = (sharePrefs?.array(forKey: shareKeys.userShares))! as! [NSDictionary]
            
            // need to mark the shares as user or system
            
            //if userMounts.count != 0 {
            //   mounts.append(contentsOf: userMounts)
            //}
            
            let mounts = mountsRaw as! [NSDictionary]
            
            let myGroups = defaults.array(forKey: Preferences.groups)
            
            for mount in mounts {
                
                // check for variable substitution
                
               // let cleanURL = subVariables(mount["URL"] as! String)
                
                // check for groups
                
                if (mount["Groups"] as! [String]).count > 0 {
                    for group in myGroups! {
                        if (mount["Groups"] as! [String]).contains(group as! String) {
                            myLogger.logit(.debug, message: "User matches groups, adding share.")
                            
                            
                            // get all the pieces
                            var currentShare = share_info(groups: mount["Groups"]! as! [String], url: URL(string: (mount["URL"] as! String).variableSwap())!, name: mount["Name"] as! String, options: mount["Options"] as! [String], connectedOnly: mount["ConnectedOnly"] as! Bool, mountStatus: .unmounted, localMount: mount["LocalMount"] as! String, autoMount: mount[shareKeys.autoMount] as! Bool, reqID: nil, attemptDate: nil, localMountPoints: nil)
                            
                            // see if we know about it
                            
                            if knownShares.contains(currentShare.url) {
                                myLogger.logit(.debug, message: "Skipping known share:" + String(describing: currentShare.url))
                            } else {
                                knownShares.append(currentShare.url)
                                all_shares.append(currentShare)
                            }
                        }
                    }
                } else {
                    
                    // get all the pieces
                    var currentShare = share_info(groups: mount["Groups"]! as! [String], url: URL(string: (mount["URL"] as! String).variableSwap())!, name: mount["Name"] as! String, options: mount["Options"] as! [String], connectedOnly: mount["ConnectedOnly"] as! Bool, mountStatus: .unmounted, localMount: mount["LocalMount"] as! String, autoMount: mount[shareKeys.autoMount] as! Bool, reqID: nil, attemptDate: nil, localMountPoints: nil)
                    
                    // see if we know about it
                    
                    if knownShares.contains(currentShare.url) {
                        myLogger.logit(.debug, message: "Skipping known share:" + String(describing: currentShare.url))
                    } else {
                        knownShares.append(currentShare.url)
                        all_shares.append(currentShare)
                    }
                }
                
            }
            refreshMounts()
        }
    }
    
    // refresh what's been mounted
    func refreshMounts() {
        
        if all_shares.count == 0 {
            return
        }
        
        for index in 0...(all_shares.count - 1) {
            if mountedShares.contains(all_shares[index].url) {
                all_shares[index].mountStatus = .mounted
                all_shares[index].localMountPoints = mountedSharePaths[all_shares[index].url]
            } else if all_shares[index].mountStatus != .mounting {
                all_shares[index].mountStatus = .unmounted
            }
        }
    }
    
    // create a dictionary for open options
    
    func openOptionsDict() -> CFMutableDictionary {
        let dict = NSMutableDictionary()
        dict[kNAUIOptionKey] = kNAUIOptionNoUI
        dict[kNetFSUseGuestKey] = false
        dict[kNetFSForceNewSessionKey] = false
        dict[kNetFSUseAuthenticationInfoKey] = true
        return dict
    }
    
    // create a dictionary for mount options
    
    func mountOptionsDict() -> NSMutableDictionary {
        let dict = NSMutableDictionary()
        dict[kNetFSSoftMountKey] = true
        return dict
    }
    
    // the actual mounting of the shares - we do this asynchronously
    
    func mountShares() {
        
        if all_shares.count == 0 {
            // no need to continue
            return
        }
        
        // find out what groups we're in
        
        let myGroups = defaults.array(forKey: Preferences.groups)
        
        for i in 0...(all_shares.count - 1) {
            
            myLogger.logit(.debug, message: "Evaluating mount: " + all_shares[i].name)
            
            // TODO: ensure the URL is reachable before attempting to mount
            
            // loop through all the reasons to not mount this share
            
            if all_shares[i].mountStatus == .mounted || all_shares[i].mountStatus == .mounting || mountedShares.contains(all_shares[i].url){
                // already mounted
                myLogger.logit(.debug, message: "Skipping mount because it's already mounted.")
                continue
            } else {
                all_shares[i].mountStatus == .unmounted
            }
            
            if !all_shares[i].autoMount {
                // not to be automounted
                myLogger.logit(.debug, message: "Skipping mount because it's not set to Automount.")
                continue
            }
            
            if all_shares[i].connectedOnly && !connectedState {
                // not connected
                myLogger.logit(.debug, message: "Skipping mount because we're not connected.")
                continue
            }
            
            if all_shares[i].mountStatus != .errorOnMount {
                
                let open_options : CFMutableDictionary = openOptionsDict()
                var mount_options = mountOptionsDict()
                
                if all_shares[i].options.count > 0 {
                    var mountFlagValue = 0
                    
                    // big thanks to @frogor for the mount flags table
                    for option in all_shares[i].options {
                        switch option {
                        case "MNT_RDONLY"            : mountFlagValue += 0x00000001
                        case "MNT_SYNCHRONOUS"       : mountFlagValue += 0x00000002
                        case "MNT_NOEXEC"            : mountFlagValue += 0x00000004
                        case "MNT_NOSUID"            : mountFlagValue += 0x00000008
                        case "MNT_NODEV"             : mountFlagValue += 0x00000010
                        case "MNT_UNION"             : mountFlagValue += 0x00000020
                        case "MNT_ASYNC"             : mountFlagValue += 0x00000040
                        case "MNT_CPROTECT"          : mountFlagValue += 0x00000080
                        case "MNT_EXPORTED"          : mountFlagValue += 0x00000100
                        case "MNT_QUARANTINE"        : mountFlagValue += 0x00000400
                        case "MNT_LOCAL"             : mountFlagValue += 0x00001000
                        case "MNT_QUOTA"             : mountFlagValue += 0x00002000
                        case "MNT_ROOTFS"            : mountFlagValue += 0x00004000
                        case "MNT_DOVOLFS"           : mountFlagValue += 0x00008000
                        case "MNT_DONTBROWSE"        : mountFlagValue += 0x00100000
                        case "MNT_IGNORE_OWNERSHIP"  : mountFlagValue += 0x00200000
                        case "MNT_AUTOMOUNTED"       : mountFlagValue += 0x00400000
                        case "MNT_JOURNALED"         : mountFlagValue += 0x00800000
                        case "MNT_NOUSERXATTR"       : mountFlagValue += 0x01000000
                        case "MNT_DEFWRITE"          : mountFlagValue += 0x02000000
                        case "MNT_MULTILABEL"        : mountFlagValue += 0x04000000
                        case "MNT_NOATIME"           : mountFlagValue += 0x10000000
                        default                      : mountFlagValue += 0
                        }
                    }
                    myLogger.logit(.debug, message: "Mount options: (mountFlagValue)")
                    mount_options[kNetFSMountFlagsKey] = mountFlagValue
                }
                
                var requestID: AsyncRequestID? = nil
                let queue = DispatchQueue.main
                
                myLogger.logit(.debug, message: "Attempting to mount: " + all_shares[i].url.absoluteString)
                var mountError: Int32? = nil
                
                mountError = NetFSMountURLAsync(all_shares[i].url as CFURL!,
                                                nil,
                                                userPrincipal as CFString!,
                                                nil,
                                                open_options,
                                                mount_options,
                                                &requestID,
                                                queue)
                {(stat:Int32, requestID:AsyncRequestID?, mountpoints:CFArray?) -> Void in
                    print(requestID!)
                    for i in 0...(self.all_shares.count - 1) {
                        if self.all_shares[i].reqID == requestID {
                            if stat == 0{
                                myLogger.logit(.debug, message: "Mounted share: " + self.all_shares[i].name)
                                self.all_shares[i].mountStatus = .mounted
                                self.all_shares[i].reqID = nil
                                let mounts = mountpoints as! Array<String>
                                self.all_shares[i].localMountPoints = mounts[0] ?? ""
                            } else {
                                myLogger.logit(.debug, message: "Error on mounting share: " + self.all_shares[i].name)
                                self.all_shares[i].mountStatus = .errorOnMount
                                self.all_shares[i].reqID = nil
                            }
                        }
                    }
                }
                all_shares[i].mountStatus = .mounting
                all_shares[i].reqID = requestID
                all_shares[i].attemptDate = Date()
                
            } else {
                // clean up any errored mounts
                let mountInterval = (all_shares[i].attemptDate?.timeIntervalSinceNow)!
                if abs(mountInterval) > 5 * 60 {
                    all_shares[i].mountStatus == .toBeMounted
                }
            }
        }
    }
    
    
    // synchronous share mount function
    // this makes the app go all beach-bally so
    // we use async mounting instead
    
    func syncMountShare(_ serverAddress: URL, options: [String], open: Bool=false) {
        
        let open_options : CFMutableDictionary = openOptionsDict()
        var mount_options = mountOptionsDict()
        
        if options.count > 0 {
            var mountFlagValue = 0
            for option in options {
                switch option {
                case "MNT_RDONLY"            : mountFlagValue += 0x00000001
                case "MNT_SYNCHRONOUS"       : mountFlagValue += 0x00000002
                case "MNT_NOEXEC"            : mountFlagValue += 0x00000004
                case "MNT_NOSUID"            : mountFlagValue += 0x00000008
                case "MNT_NODEV"             : mountFlagValue += 0x00000010
                case "MNT_UNION"             : mountFlagValue += 0x00000020
                case "MNT_ASYNC"             : mountFlagValue += 0x00000040
                case "MNT_CPROTECT"          : mountFlagValue += 0x00000080
                case "MNT_EXPORTED"          : mountFlagValue += 0x00000100
                case "MNT_QUARANTINE"        : mountFlagValue += 0x00000400
                case "MNT_LOCAL"             : mountFlagValue += 0x00001000
                case "MNT_QUOTA"             : mountFlagValue += 0x00002000
                case "MNT_ROOTFS"            : mountFlagValue += 0x00004000
                case "MNT_DOVOLFS"           : mountFlagValue += 0x00008000
                case "MNT_DONTBROWSE"        : mountFlagValue += 0x00100000
                case "MNT_IGNORE_OWNERSHIP"  : mountFlagValue += 0x00200000
                case "MNT_AUTOMOUNTED"       : mountFlagValue += 0x00400000
                case "MNT_JOURNALED"         : mountFlagValue += 0x00800000
                case "MNT_NOUSERXATTR"       : mountFlagValue += 0x01000000
                case "MNT_DEFWRITE"          : mountFlagValue += 0x02000000
                case "MNT_MULTILABEL"        : mountFlagValue += 0x04000000
                case "MNT_NOATIME"           : mountFlagValue += 0x10000000
                default                      : mountFlagValue += 0
                }
            }
            myLogger.logit(.debug, message: "Mount options: (mountFlagValue)")
            mount_options[kNetFSMountFlagsKey] = mountFlagValue
        }
        
        var mountArray: Unmanaged<CFArray>? = nil
        
        let myResult = NetFSMountURLSync(serverAddress as CFURL!, nil, nil, nil, open_options, mount_options, &mountArray)
        myLogger.logit(.debug, message: myResult.description)
        
        if let mountPoint = mountArray!.takeRetainedValue() as? [String] {
        if myResult == 0 && open {
            NSWorkspace.shared().open(URL(fileURLWithPath: mountPoint[0], isDirectory: true))
        }
        }
    }
    
    func asyncMountShare(_ serverAddress: URL, options: [String], open: Bool=false) {
        
        let open_options : CFMutableDictionary = openOptionsDict()
        var mount_options = mountOptionsDict()
        
        if options.count > 0 {
            var mountFlagValue = 0
            
            // big thanks to @frogor for the mount flags table
            for option in options {
                switch option {
                case "MNT_RDONLY"            : mountFlagValue += 0x00000001
                case "MNT_SYNCHRONOUS"       : mountFlagValue += 0x00000002
                case "MNT_NOEXEC"            : mountFlagValue += 0x00000004
                case "MNT_NOSUID"            : mountFlagValue += 0x00000008
                case "MNT_NODEV"             : mountFlagValue += 0x00000010
                case "MNT_UNION"             : mountFlagValue += 0x00000020
                case "MNT_ASYNC"             : mountFlagValue += 0x00000040
                case "MNT_CPROTECT"          : mountFlagValue += 0x00000080
                case "MNT_EXPORTED"          : mountFlagValue += 0x00000100
                case "MNT_QUARANTINE"        : mountFlagValue += 0x00000400
                case "MNT_LOCAL"             : mountFlagValue += 0x00001000
                case "MNT_QUOTA"             : mountFlagValue += 0x00002000
                case "MNT_ROOTFS"            : mountFlagValue += 0x00004000
                case "MNT_DOVOLFS"           : mountFlagValue += 0x00008000
                case "MNT_DONTBROWSE"        : mountFlagValue += 0x00100000
                case "MNT_IGNORE_OWNERSHIP"  : mountFlagValue += 0x00200000
                case "MNT_AUTOMOUNTED"       : mountFlagValue += 0x00400000
                case "MNT_JOURNALED"         : mountFlagValue += 0x00800000
                case "MNT_NOUSERXATTR"       : mountFlagValue += 0x01000000
                case "MNT_DEFWRITE"          : mountFlagValue += 0x02000000
                case "MNT_MULTILABEL"        : mountFlagValue += 0x04000000
                case "MNT_NOATIME"           : mountFlagValue += 0x10000000
                default                      : mountFlagValue += 0
                }
            }
            myLogger.logit(.debug, message: "Mount options: (mountFlagValue)")
            mount_options[kNetFSMountFlagsKey] = mountFlagValue
        }
        
        var requestID: AsyncRequestID? = nil
        let queue = DispatchQueue.main
        
        myLogger.logit(.debug, message: "Attempting to mount: " + String(describing: serverAddress))
        var mountError: Int32? = nil
        
        mountError = NetFSMountURLAsync(serverAddress as CFURL!,
                                        nil,
                                        userPrincipal as CFString!,
                                        nil,
                                        open_options,
                                        mount_options,
                                        &requestID,
                                        queue)
        {(stat:Int32, requestID:AsyncRequestID?, mountpoints:CFArray?) -> Void in
            
            if stat == 0 {
                    myLogger.logit(.debug, message: "Mounted share: " + String(describing: serverAddress))
                
                if let mountPoint = (mountpoints! as! [String]).first {
                    NSWorkspace.shared().open(URL(fileURLWithPath: mountPoint, isDirectory: true))
                }
            } else {
                myLogger.logit(.debug, message: "Error mounting share: " + String(describing: serverAddress))
            }
        }
    }
    
    // function to determine what shares may be already mounted
    
    func getMountedShares() {
        let fm = FileManager.default
        
        // zero out the currently mounted shares
        
        mountedShares.removeAll()
        mountedSharePaths.removeAll()
        
        let myShares = fm.mountedVolumeURLs(includingResourceValuesForKeys: nil, options: FileManager.VolumeEnumerationOptions(rawValue: 0))
        
        myLogger.logit(.debug, message: "Currently mounted shares: " + String(describing: myShares))
        
        for share in myShares! {
            
            var myDes: NSString? = nil
            var myType: NSString? = nil
            
            // need to watch out for funky VM shares
            
            guard ws.getFileSystemInfo(forPath: share.path, isRemovable: nil, isWritable: nil, isUnmountable: nil, description: &myDes, type: &myType) else {
                myLogger.logit(.debug, message: "Get File info failed. Probably a synthetic Shared Folder.")
                
                // skip this share and move on to the next
                continue
            }
            
            // ocassionaly we get a crash here on getting the retained value of the pointer, so let's wrap in a do/catch
            
            do {
                switch myType! {
                case "smbfs"    :
                    myLogger.logit(.debug, message: "Volume: " + share.path + " is a SMB network volume.")
                    let shareURL = getURL(share: share)
                    mountedShares.append(shareURL)
                    mountedSharePaths[shareURL] = share.path
                case "afpfs"    :
                    myLogger.logit(.debug, message: "Volume: " + share.path + " is an AFP network volume.")
                    let shareURL = getURL(share: share)
                    mountedShares.append(shareURL)
                    mountedSharePaths[shareURL] = share.path
                case "nfsfs"    :
                    myLogger.logit(.debug, message: "Volume: " + share.path + " is a NFS network volume.")
                    let shareURL = getURL(share: share)
                    mountedShares.append(shareURL)
                    mountedSharePaths[shareURL] = share.path
                case "webdavfs"    :
                    myLogger.logit(.debug, message: "Volume: " + share.path + " is a WebDAV network volume.")
                    let shareURL = getURL(share: share)
                    mountedShares.append(shareURL)
                    mountedSharePaths[shareURL] = share.path
                default :
                    // not a remote share
                    myLogger.logit(.debug, message: "Volume: " + share.path + " is not a network volume.")
                }
            } catch {
                myLogger.logit(.debug, message: "Problem getting the retained value of the share.")
                continue
            }
        }
        myLogger.logit(.debug, message: "Mounted shares: " + String(describing: mountedShares) )
    }
    
    private func getURL(share: URL) -> URL {
        let shareURLUnmanaged = NetFSCopyURLForRemountingVolume(share as CFURL)
        if shareURLUnmanaged != nil {
            let shareURL: URL = shareURLUnmanaged?.takeRetainedValue() as! URL
            return URL(string: (shareURL.scheme! + "://" + shareURL.host! + shareURL.path.addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlPathAllowed)!))!
        } else {
            return URL(fileURLWithPath: "")
        }
    }
    
    fileprivate func subVariables(_ url: String) -> String? {
        // TODO: get e-mail address as a variable
        var createdURL = url
        
        guard let domain = defaults.string(forKey: Preferences.aDDomain),
            let fullName = defaults.string(forKey: Preferences.displayName)?.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed),
            let serial = getSerial().addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed),
            let shortName = defaults.string(forKey: Preferences.userShortName)
            else {
                myLogger.logit(.base, message: "Error doing variable substitution on file share.")
                return nil
        }
        // filter out any blank spaces too
        
        createdURL = createdURL.replacingOccurrences(of: " ", with: "%20")
        createdURL = createdURL.replacingOccurrences(of: "<<domain>>", with: domain)
        createdURL = createdURL.replacingOccurrences(of: "<<fullname>>", with: fullName)
        createdURL = createdURL.replacingOccurrences(of: "<<serial>>", with: serial)
        createdURL = createdURL.replacingOccurrences(of: "<<shortname>>", with: shortName)
        return createdURL.addingPercentEncoding(withAllowedCharacters: .alphanumerics)
    }
}
