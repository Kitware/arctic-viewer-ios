//
//  Paths.swift
//  ArcticViewer
//
//  Created by Tristan on 7/17/15.
//  Copyright (c) 2015 Kitware. All rights reserved.
//

import Foundation

 class Paths {

    let applicationDocumentsDirectory:URL!
    let applicationInboxDirectory:URL!
    let applicationLibraryDirectory:URL!

    init(){
        var paths:[AnyObject] = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true) as [AnyObject]
        self.applicationDocumentsDirectory = URL(string: paths[0] as! String)!

        paths = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.libraryDirectory, FileManager.SearchPathDomainMask.userDomainMask, true) as [AnyObject]
        self.applicationLibraryDirectory = URL(string: paths[0] as! String)!

        self.applicationInboxDirectory = self.applicationDocumentsDirectory.appendingPathComponent("Inbox")
    }

    func tmpDirectory() -> URL {
        return self.applicationLibraryDirectory.appendingPathComponent("tmp")
    }

    func datasetsDirectory() -> URL {
        return self.applicationDocumentsDirectory
    }

    func datasetsSubdirectory(_ sub:String) -> URL {
        return self.datasetsDirectory().appendingPathComponent(sub)
    }

    func webcontentDirectory() -> URL {
        return self.applicationLibraryDirectory.appendingPathComponent("web_content")
    }

    func webcontentData() -> URL {
        return self.webcontentDirectory().appendingPathComponent("data")
    }
}
