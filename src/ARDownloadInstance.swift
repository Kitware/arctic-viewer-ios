//
//  ARDownloadInstance.swift
//  ArcticViewer
//
//  Created by Tristan on 7/23/15.
//  Copyright (c) 2015 Kitware. All rights reserved.
//

/*
    A shared instance used for downloading with some persistent variables:
    delegate - adheres to ARDownloadInstanceDelegate protocol, should inherit from
        NSURLSessionDelegate and NSURLSessionDownloadDelegate.
    progress - progress variable which when updated calls the delegate method `progressUpdated`.
    downloadTitle - title of the download.
    downloadTask - the delegate takes this and listens to it.
*/

import Foundation

protocol ARDownloadInstanceDelegate {
    func progressUpdated(_ newVal:Float)
}

class ARDownloadInstance:NSObject {
    var delegate:ARDownloadInstanceDelegate!
    var progress:Float = 0.0 {
        didSet{
            self.delegate.progressUpdated(self.progress)
        }
    }
    var downloadTitle:String = ""
    var downloadTask:URLSessionDownloadTask?

    class var sharedInstance:ARDownloadInstance {
        struct Static {
            static var sharedInstance: ARDownloadInstance = ARDownloadInstance()
        }

        return Static.sharedInstance
    }
}
