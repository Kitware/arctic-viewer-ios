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

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.

        //register store defaults.
        let store:UserDefaults = UserDefaults.standard
        store.register(defaults: [
            "first-start-setup": false,
            "first-start-version-fetching": false,

            "data-folder-sizes": [String:String](),
            "data-folder-thumbs": [String:String](),

            "arctic-web-version": "v0.7.3",
            "arctic-web-tags:": ["v0.7.3"],

            "fullscreen-viewer": false,
            "fullscreen-default-alert": false,
            "fullscreen-alert-times": 0
            ]);

        // folder setup, only do this once
        let manager:FileManager = FileManager.default
        if !store.bool(forKey: "first-start-setup") {
            //datasets will download here, place an empty file to make sure it's ok.
            let datasetDocsPath:URL = self.paths.datasetsSubdirectory(".nada")
            manager.createFile(atPath: datasetDocsPath.path, contents: nil, attributes: nil)

            do {
                //disable iCloud backup of datasets
                let datasetFilePath:URL = URL(fileURLWithPath: datasetDocsPath.absoluteString)
                try (datasetFilePath as NSURL).setResourceValue(NSNumber(value: true as Bool), forKey: URLResourceKey.isExcludedFromBackupKey)

                //tmp folder for new ArcticViewer versions
                let tmpFolder:URL = paths.tmpDirectory() as URL
                try manager.createDirectory(atPath: tmpFolder.absoluteString, withIntermediateDirectories: false, attributes: nil)

                //copy web_content from bundle to /Library
                let webContentPath:URL = URL(string: Bundle.main.resourcePath! + "/web_content")!
                let webContentDocPath:URL = self.paths.webcontentDirectory() as URL
                //try manager.removeItemAtPath(webContentDocPath.absoluteString)
                try manager.createDirectory(atPath: webContentDocPath.absoluteString, withIntermediateDirectories: false, attributes: nil)

                let files:[AnyObject] = try manager.contentsOfDirectory(atPath: webContentPath.absoluteString) as [AnyObject]
                //this will not copy directories
                for file:String in files as! [String] {
                    try manager.copyItem(atPath: webContentPath.absoluteString + "/" + file, toPath: webContentDocPath.absoluteString + "/" + file)
                }
            } catch {
                print("folder setup error!")
                print((error as NSError).localizedDescription)
            }

            store.set(true, forKey: "first-start-setup")
        }

        if !manager.fileExists(atPath: Paths().webcontentDirectory().path + "/config.json") {
            do {
                try manager.copyItem(atPath: Bundle.main.resourcePath! + "/web_content/config.json",
                    toPath: Paths().webcontentDirectory().path + "/config.json")
            } catch {
                print((error as NSError).localizedDescription)
            }
        }

        if let url:URL = launchOptions?[UIApplicationLaunchOptionsKey.url] as? URL {
            self.handleURL(url)
        }

        return true
    }

    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        // if this gets opened up to support .arctic, or arctic://[url] this will need to be refactored slightly.
        if url.isFileURL {
            self.handleURL(url)
            return true
        }
        else {
            return false
        }
    }

    func handleURL(_ url:URL) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: "InboxFile"), object: url)
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
}

