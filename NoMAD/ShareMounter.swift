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

class ShareMounter {
    
    var shares: [String: AnyObject]?
    
    init() {
        shares = defaults.dictionaryForKey("Shares")
    }
    
    func mount() {
        let groups = defaults.objectForKey("Groups")
        for share in shares! {
           // let shareGroups = share["groups"]
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
    
    
    func asyncMountShare(serverAddress: String, shareName: String) {
        
        let escapedAddress = serverAddress.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
        let shareAddress = NSURL(string: escapedAddress!)!
        
        let openOptions : CFMutableDictionary = openOptionsDict()
        let mount_options : CFMutableDictionary = mountOptionsDict()
        
        var requestID: AsyncRequestID = nil
        let queue = dispatch_get_main_queue()
        
        NetFSMountURLAsync(shareAddress, nil, nil, nil, openOptions, mount_options, &requestID, queue)
        {(stat:Int32,  requestID:AsyncRequestID,  mountpoints:CFArray!) -> Void in
            print("msg: \(stat) mountpoint: \(mountpoints)")
        }
    }
    
    func getNetworkShares() {
    let fm = NSFileManager.defaultManager()
    
    let myShares = fm.mountedVolumeURLsIncludingResourceValuesForKeys(nil, options: NSVolumeEnumerationOptions.SkipHiddenVolumes)
    
    let ws = NSWorkspace.init()
    
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


