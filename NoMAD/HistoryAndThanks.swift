//
//  HistoryAndThanks.swift
//  NoMAD
//
//  Created by Joel Rennich on 4/10/17.
//  Copyright © 2017 Orchard & Grove Inc. All rights reserved.
//

import Foundation

class HistoryAndThanks {
    
    init() {
        // in the beginning....
        
        // NoMAD wouldn't be here without the help of many people before me and projects that inspired it's development
        
        // Many thanks go out, in no particular order:
        // Ben Toms, Phillip Boushy, Peter Bukowinski, Francois Levaux-Tiffreau, Owen Pragel, Michael Lynn, Kyle Crawshaw and the rest of the #secretgroup Slack Channel
        
        let thanks = "👏👏👏👏👏👏👏👏👏👏"
        print(thanks)
    }
    
    func getHistory() -> URL {
        
        // Ben did a great job of summing up a lot of the history and the people involved in his post
        // you should read it if you have any interest in how a lot of projects and people are connected
        
        return URL.init(string: "https://macmule.com/2017/04/01/adpassmon-is-dead-long-live-nomad/")!
    }
    
    func firstPublicPosting() -> URL {
        
        // this was the first public posting about NoMAD as a product that wasn't just some chatter in a Slack channel - August 2, 2016
        
        return URL.init(string: "https://maclovin.org/blog-native/2016/nomad-get-ad-features-without-binding-your-mac")!
    }
    
    func projectsBeforeNoMAD() -> [String] {
        
        var existingWork = [String]()
        
        existingWork.append("ADPassMon")
        existingWork.append("ShareMounter")
        existingWork.append("KerbMinder")
        existingWork.append("AD Password Monitor")
        existingWork.append("Gala")

        return existingWork
    }
    
    func thingsYouMayNotKnow() -> String {
        
        // putting this here for possible future Easter Eggs on the MacAdmins podcast, we'll see if Charles or Tom find it. I bet Charles does, but then he'll forget he found it.
        
        var esotericBits = ""
        
        esotericBits.append("The original working name of NoMAD was NoAD. That didn't roll of the tongue so well.\n")
        esotericBits.append("NoAD's first commit was April 19, 2016. However, it was only superficially similar to what NoMAD is today.\n")
        esotericBits.append("NoMAD is short for No Mo' Active Directory.\n")
        esotericBits.append("The original repo was on a private BitBucket account, which I think still exists.\n")
        esotericBits.append("It really was an attempt to get Ben Toms to do more with Swift, and wasn't really intended to be a project on it's own.\n")
        esotericBits.append("Carrie the Caribou, the NoMAD mascot, is named after Carrie Fisher who died as we were designing the logo.\n")
        esotericBits.append("Although I'm not really sure if female caribou have antlers... should probably look into that.\n")
        esotericBits.append("The caribou is the most nomadic land mammal, hence why a such a majastic gentle giant of the North graces the NoMAD icon.\n")
        esotericBits.append("It's even possible that we are here because of the caribou - https://en.wikipedia.org/wiki/Gwich%27in.\n")
        esotericBits.append("I first publicly discussed NoMAD on the MacAdmins podcast on Sept. 5, 2016. My second appearance in that podcast was where I didin't record my audio and we had to do it all over again.\n")
        esotericBits.append("The first conference where I talked about NoMAD was at MacSysAdmin 2016. You can find the session on the site, macsysadmin.se\n")
        esotericBits.append("NoMAD was officially launched at the University of Utah Mac Managers meeting on Dec. 21, 2016.\n")
        esotericBits.append("Version 1.1 took waaay longer than it was supposed to.")
        esotericBits.append("MacSysAdmin 2017 is where we'll show off NoMAD 2.0 for the first time in public. Note to self... better get working on that.")
        
        return esotericBits
    }
}
