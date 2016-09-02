//
//  ShareMounter.swift
//  NoMAD
//
//  Created by Joel Rennich on 8/29/16.
//  Copyright © 2016 Trusource Labs. All rights reserved.
//

// mad props to Kyle Crawshaw
// since much of this is cribbed from Share Mounter

import Foundation
import NetFS

struct share_info {
    var groups: [String]
    var share_url: String
    var title: String
}

class ShareMounter {
    
    var all_shares = [share_info]()
    let ws = NSWorkspace.init()
    
    init() {
        // read in the preference files
        
        let prefs = ["/Library/Preferences/ShareMounter.plist", NSHomeDirectory() + "/Library/Preferences/ShareMounter.plist"]
        
        for place in prefs {
            let myDictionary = NSDictionary.init(contentsOfFile: place)
            
            if myDictionary != nil {
                let shares = (myDictionary?.objectForKey("network_shares"))! as! [AnyObject]
                
                for i in shares {
                    let currentShare = share_info(groups: i.objectForKey("groups")! as! Array, share_url: i.objectForKey("share_url")! as! String, title: i.objectForKey("title")! as! String)
                    all_shares.append(currentShare)
                }
            }
        }
            
    }
    
    func mount() {
        
        let myGroups = defaults.arrayForKey("Groups")
    
        for share in all_shares {
            for group in myGroups! {
                if share.groups.contains(group as! String) {
                // time to mount
                    NSLog("Attempting to mount: " + share.share_url)
                    asyncMountShare(share.share_url)
                    break
                }
            }
        }
    }
    
    func openOptionsDict() -> CFMutableDictionary {
        let dict = NSMutableDictionary()
        dict[kNAUIOptionKey] = kNAUIOptionAllowUI
        dict[kNetFSUseGuestKey] = true
        return dict
    }
    
    func mountOptionsDict() -> CFMutableDictionary {
        let dict = NSMutableDictionary()
        return dict
    }
    
    
    func asyncMountShare(serverAddress: String) {
        
        let escapedAddress = serverAddress.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
        let shareAddress = NSURL(string: escapedAddress!)!
        
        //let openOptions : CFMutableDictionary = openOptionsDict()
        //let mount_options : CFMutableDictionary = mountOptionsDict()
        
        var requestID: AsyncRequestID = nil
        let queue = dispatch_get_main_queue()
        
        NetFSMountURLAsync(shareAddress, nil, defaults.stringForKey("userPrincipal")!, nil, nil, nil, &requestID, queue)
        {(stat:Int32,  requestID:AsyncRequestID,  mountpoints:CFArray!) -> Void in
            print("msg: \(stat) mountpoint: \(mountpoints)")
        }
    }
    
    func getNetworkShares() {
    let fm = NSFileManager.defaultManager()
    
    let myShares = fm.mountedVolumeURLsIncludingResourceValuesForKeys(nil, options: NSVolumeEnumerationOptions.SkipHiddenVolumes)
    
    for share in myShares! {
    
    var myDes: NSString? = nil
    var myType: NSString? = nil
    
    ws.getFileSystemInfoForPath(share.path!, isRemovable: nil, isWritable: nil, isUnmountable: nil, description: &myDes, type: &myType)
    print(myType!)
    if myType! == "smbfs" {
    print("Volume: " + share.path! + " is an SMB network volume.")
    }
}
    }
}


