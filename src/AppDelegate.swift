//
//  AppDelegate.swift
//  ArcticViewer
//
//  Created by Tristan on 7/13/15.
//  Copyright (c) 2015 Kitware. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    let paths:Paths = Paths()

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.

        //register store defaults.
        let store:NSUserDefaults = NSUserDefaults.standardUserDefaults()
        store.registerDefaults([
            "first-start-setup": false,
            "first-start-version-fetching": false,

            "data-folder-sizes": [String:String](),
            "data-folder-thumbs": [String:String](),

            "arctic-web-version": "v0.0.5",
            "arctic-web-tags:": ["v0.0.5"],

            "fullscreen-viewer": false,
            "fullscreen-default-alert": false,
            "fullscreen-alert-times": 0
            ]);

        // folder setup, only do this once
        if !store.boolForKey("first-start-setup") {
            let manager:NSFileManager = NSFileManager.defaultManager()

            //datasets will download here, place an empty file to make sure it's ok.
            let datasetDocsPath:NSURL = self.paths.datasetsSubdirectory(".nada")
            manager.createFileAtPath(datasetDocsPath.path!, contents: nil, attributes: nil)

            //disable iCloud backup of datasets
            let datasetFilePath:NSURL = NSURL(fileURLWithPath: datasetDocsPath.absoluteString!)!
            datasetFilePath.setResourceValue(NSNumber(bool: true), forKey: NSURLIsExcludedFromBackupKey, error: nil)

            //tmp folder for new ArcticViewer versions
            let tmpFolder:NSURL = paths.tmpDirectory()
            manager.createDirectoryAtPath(tmpFolder.absoluteString!, withIntermediateDirectories: false, attributes: nil, error: nil)

            //copy web_content from bundle to library
            let webContentPath:NSURL = NSURL(string: NSBundle.mainBundle().resourcePath! + "/web_content")!
            let webContentDocPath:NSURL = self.paths.webcontentDirectory()
            manager.removeItemAtPath(webContentDocPath.absoluteString!, error: nil)
            let created:Bool = manager.createDirectoryAtPath(webContentDocPath.absoluteString!, withIntermediateDirectories: false, attributes: nil, error: nil)
            println("web_content created: \(created)")

            let files:[AnyObject] = manager.contentsOfDirectoryAtPath(webContentPath.absoluteString!, error: nil)!

            //this will not copy directories
            for file:String in files as! [String] {
                manager.copyItemAtPath(webContentPath.absoluteString! + "/" + file, toPath: webContentDocPath.absoluteString! + "/" + file, error: nil)
            }

            store.setBool(true, forKey: "first-start-setup")
        }

        if let url:NSURL = launchOptions?[UIApplicationLaunchOptionsURLKey] as? NSURL {
            self.handleURL(url)
        }

        return true
    }

    func application(application: UIApplication, openURL url: NSURL, sourceApplication: String?, annotation: AnyObject?) -> Bool {
        // if this gets opened up to support .arctic, or arctic://[url] this will need to be refactored slightly.
        if url.fileURL {
            self.handleURL(url)
            return true
        }
        else {
            return false
        }
    }

    func handleURL(url:NSURL) {
        NSNotificationCenter.defaultCenter().postNotificationName("InboxFile", object: url)
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
}

