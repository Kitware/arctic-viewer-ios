//
//  Paths.swift
//  ArcticViewer
//
//  Created by Tristan on 7/17/15.
//  Copyright (c) 2015 Kitware. All rights reserved.
//

import Foundation

 class Paths {

    let applicationDocumentsDirectory:NSURL!
    let applicationInboxDirectory:NSURL!
    let applicationLibraryDirectory:NSURL!

    init(){
        var paths:[AnyObject] = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true)
        self.applicationDocumentsDirectory = NSURL(string: paths[0] as! String)!

        paths = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.LibraryDirectory, NSSearchPathDomainMask.UserDomainMask, true)
        self.applicationLibraryDirectory = NSURL(string: paths[0] as! String)!

        self.applicationInboxDirectory = self.applicationDocumentsDirectory.URLByAppendingPathComponent("Inbox")
    }

    func tmpDirectory() -> NSURL {
        return self.applicationLibraryDirectory.URLByAppendingPathComponent("tmp")
    }

    func datasetsDirectory() -> NSURL {
        return self.applicationDocumentsDirectory
    }

    func datasetsSubdirectory(sub:String) -> NSURL {
        return self.datasetsDirectory().URLByAppendingPathComponent(sub)
    }

    func webcontentDirectory() -> NSURL {
        return self.applicationLibraryDirectory.URLByAppendingPathComponent("web_content")
    }

    func webcontentData() -> NSURL {
        return self.webcontentDirectory().URLByAppendingPathComponent("data")
    }
}