//
//  ShareMounter.swift
//  NoMAD
//
//  Created by Joel  on 8/29/16.
//  Copyright © 2016 Trusource Labs. All rights reserved.
//

// mad props to Kyle Crawshaw
// since much of this is cribbed from Share Mounter

import Cocoa
import Foundation
import NetFS
import CoreServices

enum mountStatus: Int {
    case unmounted = 0
    case toBeMounted = 1
    case notInGroup = 2
    case mounting = 3
    case mounted = 4
    case errorOnMount = 5
}

struct share_info {
    var groups: [String]
    var share_url: URL
    var title: String
    var options: [String]
    var mountStatus: mountStatus?
}

struct mounting_shares_info {
    var share_url: URL
    var reqID: AsyncRequestID?
    var mount_time: Date
}

class ShareMounter {

    var all_shares = [share_info]()
    let ws = NSWorkspace.init()
    //var prefs: [String]
    lazy var userPrincipal: String = ""
    var mountedShares = [URL]()
    lazy var shareCount = 0
    lazy var myGroups = [String]()
    lazy var mountHome: Bool = false
    lazy var all_mounting_shares = [mounting_shares_info]()
    let shareDefaults = UserDefaults.init(suiteName: "com.trusourcelabs.NoMAD.Shares")

    //lazy var sharesMounting = [URL]()

    init() {
        // read in the preference files
        myLogger.logit(.debug, message: "Looking for ShareMounter preferences.")
        //prefs = ["/Library/Preferences/ShareMounter.plist", NSHomeDirectory() + "/Library/Preferences/ShareMounter.plist"]
    }

    func mount() {
        for share in all_shares {
            if !mountedShares.contains(share.share_url) {
                for group in myGroups {
                    if share.groups.contains(group) || share.groups == [""] {
                        // time to mount
                        shareCount += 1
                        //print("***Incrementing shareCount***")
                        //print(shareCount)
                        myLogger.logit(.debug, message: "Attempting to mount: " + String(describing: share.share_url))
                        asyncMountShare(share.share_url, options: share.options)
                        break
                    }
                }
            } else {
                myLogger.logit(.debug, message: "Already mounted.")
            }
        }
    }

    // function to find shares from ShareMounter.plist files

    func getSharesToMount() {
        // zero out the shares to mount
        all_shares.removeAll()

        // TODO: use defaults
        // TODO: don't rewrite the same share into the list of shares to be mounted

        for place in prefs {
            let myDictionary = NSDictionary.init(contentsOfFile: place)
            if myDictionary != nil {
                if (myDictionary?.object(forKey: "include_smb_home"))! as! Bool && defaults.string(forKey: Preferences.userHome) != "" {
                    myLogger.logit(.debug, message: "Including user home in shares to mount.")
                    let currentShare = share_info(groups: [""], share_url: URL(string: "smb:" + (defaults.string(forKey: Preferences.userHome))!)!, title: "Home Sharepoint", options: [], mountStatus: mountStatus.toBeMounted)
                    self.all_shares.append(currentShare)
                } else {
                    myLogger.logit(.debug, message: "Not including user home in shares to mount.")
                }
                let shares = (myDictionary?.object(forKey: "network_shares"))! as! [NSDictionary]
                for i in shares {
                    // pull any options that may be included
                    let mountOptions = i.object(forKey: "mount_options") ?? []
                    let currentShare = share_info(groups: i.object(forKey: "groups")! as! Array, share_url: URL(string: i.object(forKey: "share_url")! as! String)!, title: i.object(forKey: "title")! as! String, options: mountOptions as! [String],mountStatus: mountStatus.toBeMounted )
                    self.all_shares.append(currentShare)
                }
            }
        }
        myLogger.logit(.debug, message: "Shares to be mounted: " + String(describing: all_shares))
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

    func asyncMountShare(_ serverAddress: URL, options: [String]) {

        // TODO: ensure the URL is reachable before attempting to mount

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

        let mounting_share = mounting_shares_info(share_url: serverAddress, reqID: &requestID, mount_time: Date())
        all_mounting_shares.append(mounting_share)

        let mountError = NetFSMountURLAsync(serverAddress as CFURL!,
                                            nil,
                                            userPrincipal as CFString!,
                                            nil,
                                            open_options,
                                            mount_options,
                                            &requestID,
                                            queue)
        {(stat:Int32, requestID:AsyncRequestID?, mountpoints:CFArray?) -> Void in
            myLogger.logit(.debug, message: "Mounted \(mountpoints)")
            print(requestID!)
            //print("***Decrementing shareCount***")
            //print(self.shareCount)

            self.shareCount -= 1
        }
        myLogger.logit(.base, message: "Mounting error: " + String(describing: mountError))
    }

    // synchronous share mount function
    // this makes the app go all beach-bally so
    // we use async mounting instead

    func syncMountShare(_ serverAddress: URL, options: [String]) {

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


        let myResult = NetFSMountURLSync(serverAddress as CFURL!, nil, nil, nil, open_options, mount_options, nil)
        myLogger.logit(.debug, message: myResult.description)
    }

    // function to determine what shares may be already mounted

    func getMountedShares() {
        let fm = FileManager.default

        // zero out the currently mounted shares

        mountedShares.removeAll()

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
                    myLogger.logit(.debug, message: "Volume: " + share.path + " is an SMB network volume.")
                    let shareCFURL = NetFSCopyURLForRemountingVolume(share as CFURL!).takeRetainedValue() as NSURL
                    let shareURL = URL(string: (shareCFURL.scheme! + "://" + shareCFURL.host! + shareCFURL.path!))
                    mountedShares.append(shareURL!)
                case "afpfs"    :
                    myLogger.logit(.debug, message: "Volume: " + share.path + " is an AFP network volume.")
                    let shareCFURL = NetFSCopyURLForRemountingVolume(share as CFURL!).takeRetainedValue() as NSURL
                    let shareURL = URL(string: (shareCFURL.scheme! + "://" + shareCFURL.host! + shareCFURL.path!))
                    mountedShares.append(shareURL!)
                case "nfsfs"    :
                    myLogger.logit(.debug, message: "Volume: " + share.path + " is an NFS network volume.")
                    let shareCFURL = NetFSCopyURLForRemountingVolume(share as CFURL!).takeRetainedValue() as NSURL
                    let shareURL = URL(string: (shareCFURL.scheme! + "://" + shareCFURL.host! + shareCFURL.path!))
                    mountedShares.append(shareURL!)
                case "webdavfs"    :
                    myLogger.logit(.debug, message: "Volume: " + share.path + " is a WebDAV network volume.")
                    let shareCFURL = NetFSCopyURLForRemountingVolume(share as CFURL!).takeRetainedValue() as NSURL
                    let shareURL = URL(string: (shareCFURL.scheme! + "://" + shareCFURL.host! + shareCFURL.path!))
                    mountedShares.append(shareURL!)
                default :
                    // not a remote share
                    myLogger.logit(.debug, message: "Volume: " + share.path + " is not a network volume.")
                }
            } catch {
                myLogger.logit(.debug, message: "Promblem getting the retained value of the share.")
                continue
            }
        }
        myLogger.logit(.debug, message: "Mounted shares: " + String(describing: mountedShares) )
    }
}
