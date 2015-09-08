//
//  MainViewController.swift
//  ArcticViewer
//
//  Created by Tristan on 7/14/15.
//  Copyright (c) 2015 Kitware. All rights reserved.
//

import UIKit

class MainViewController: UITableViewController, UITableViewDelegate, UITableViewDataSource,
    UINavigationControllerDelegate,
    UIAlertViewDelegate {

    let paths:Paths = Paths()
    let store:NSUserDefaults = NSUserDefaults.standardUserDefaults()
    var progress:NSProgress!
    let NVHProgressObserverContext:UnsafeMutablePointer<Void> = UnsafeMutablePointer<Void>()
    
    @IBOutlet var table: UITableView!
    var dataFolders:[String] = []
    var cellToDelete:Int = -1
    var dataFolderSizes:[String:String]!
    var dataFolderThumbs:[String:String]!
    var deflating:Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "Datasets"

        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("handleURL:"), name: "InboxFile", object: nil)
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        let path:String = self.paths.datasetsDirectory().absoluteString!
        self.dataFolders = (NSFileManager.defaultManager().contentsOfDirectoryAtPath(path, error: nil) as! [String])
            .filter({ (obj:String) in
                if obj.hasSuffix(".tar.gz") || obj.hasSuffix(".tgz") {
                    //remove the extension so it doesn't defalting twice
                    let newName:String = obj.componentsSeparatedByString(".").first!
                    if let url:NSURL = NSURL(string: path)?.URLByAppendingPathComponent(obj) {
                        println("deflating!")
                        let newURL:NSURL = NSURL(string: path)!.URLByAppendingPathComponent(newName)
                        NSFileManager.defaultManager().moveItemAtPath(url.path!, toPath: newURL.path!, error: nil)
                        NSNotificationCenter.defaultCenter().postNotificationName("InboxFile", object: newURL)
                    }
                    return false
                }
                return obj != "Inbox" && self.isDirectory(path + "/" + obj)
            })

        self.table.reloadData()

        //cleanse cached values
        self.dataFolderSizes = store.dictionaryForKey("data-folder-sizes") as! [String:String]
        let filteredMetadataKeys:[String] = self.dataFolderSizes.keys.array.filter({el in
            return contains(self.dataFolders, el)
        })

        var tmpMetaData:[String:String] = Dictionary()
        for file:String in filteredMetadataKeys {
            tmpMetaData[file] = self.dataFolderSizes[file]
        }
        self.dataFolderSizes = tmpMetaData
        self.store.setObject(tmpMetaData, forKey: "data-folder-sizes")

        self.dataFolderThumbs = store.dictionaryForKey("data-folder-thumbs") as! [String:String]
        //println("\(self.dataFolderSizes)\n\(self.dataFolderThumbs)")
    }

    override func viewWillDisappear(animated: Bool) {
        self.store.setObject(self.dataFolderSizes, forKey: "data-folder-sizes")
        self.store.synchronize()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    //MARK: TableView Delegates
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.dataFolders.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell:MainViewTableCell = self.table.dequeueReusableCellWithIdentifier("cell") as! MainViewTableCell

        let title:String = self.dataFolders[indexPath.row]
        cell.title?.text = title

        if let size:String = self.dataFolderSizes[title] {
            cell.subtitle?.text = "Size: " + size
        }
        else if self.deflating && indexPath.row == self.dataFolders.count - 1 {
            cell.subtitle?.text = "Decompressing dataset..."
        }
        else {
            //this can fail for very large files if synchronus.
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), {
                let size:String = self.sizeForFolder(title)
                cell.subtitle?.text = "Size: " + size

                self.dataFolderSizes[title] = size
                self.store.setObject(self.dataFolderSizes, forKey: "data-folder-sizes")
            })
            cell.subtitle?.text = "Size: calculating..."
        }

        //see if there's an available thumbnail in the dataset
        if let image:UIImage = self.offlineThumbnail(title) {
//            println("offline thumb")
            cell.thumb?.image = image
        }
        // fetch the thumbnail from a url or the sd-web image cache?
        else if let imageSrc:String = self.dataFolderThumbs[title] {
//            println("cached thumb")
            cell.thumb?.sd_setImageWithURL(NSURL(string:imageSrc))
        }
        // set the thumbnail to the null-image
        else {
            cell.thumb?.image = UIImage(named: "null-image", inBundle: NSBundle.mainBundle(), compatibleWithTraitCollection: nil)
        }

        return cell
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)

        if self.deflating && indexPath.row == self.dataFolders.count - 1 {
            println("not available")
            return
        }

        let webContentPath:NSURL = self.paths.webcontentData()
        let dataPath:NSURL = self.paths.datasetsSubdirectory(dataFolders[indexPath.row])

        let error:NSErrorPointer = NSErrorPointer()
        NSFileManager.defaultManager().removeItemAtPath(webContentPath.absoluteString!, error: nil)
        NSFileManager.defaultManager().createSymbolicLinkAtPath(webContentPath.absoluteString!, withDestinationPath: dataPath.absoluteString!, error: error)

        if error != nil {
            println("problem creating symlink")
            println(error.debugDescription)
            return
        }

        presentTonicView(self.dataFolders[indexPath.row])
    }

    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        self.cellToDelete = indexPath.row
        let alert:UIAlertView = UIAlertView(title: "Delete dataset?", message: "\(self.dataFolders[indexPath.row]) will be deleted from the device.", delegate: self, cancelButtonTitle: "Delete", otherButtonTitles: "Cancel")
        alert.show()
    }

    // MARK: misc
    func offlineThumbnail(name:String) -> UIImage? {
        let path:NSURL = self.paths.datasetsSubdirectory(name)
        let list:[AnyObject]? = NSFileManager.defaultManager().contentsOfDirectoryAtPath(path.absoluteString!, error: nil)
        var image:UIImage? = nil
        for file:String in list as! [String] {
            if (file.hasSuffix(".png") || file.hasSuffix(".jpg") || file.hasSuffix(".jpeg")) && !file.hasPrefix(".") {
                return UIImage(contentsOfFile: path.URLByAppendingPathComponent(file).absoluteString!)
            }
        }
        return nil
    }

    func handleURL(notifURL:NSNotification) {
        if let url:NSURL = notifURL.object as? NSURL {
            let fName:String = url.lastPathComponent!.componentsSeparatedByString(".").first!
            self.preparDeflate()
            dispatch_async(dispatch_get_main_queue(), {
                self.dataFolders.append(fName)
                self.deflating = true
                self.table.reloadData()

                NVHTarGzip.sharedInstance().unTarGzipFileAtPath(url.path!, toPath: self.paths.datasetsDirectory().path!,
                completion: { (error:NSError!) -> Void in
                    self.completeDeflate(error)
                    self.deflating = false
                    self.table.reloadData()

                    NSFileManager.defaultManager().removeItemAtPath(url.path!, error: nil)
                })
            })
        }
    }
    
    func preparDeflate() {
        self.progress = NSProgress(totalUnitCount: 1)
        let keyPath:String = "fractionCompleted"
        self.progress.addObserver(self, forKeyPath: keyPath,
            options: NSKeyValueObservingOptions.Initial,
            context: self.NVHProgressObserverContext)
        self.progress.becomeCurrentWithPendingUnitCount(1)
    }
    
    func completeDeflate(error:NSError!) {
        let keyPath:String = "fractionCompleted"
        if error != nil {
            println("issue decompressing!")
        }
        self.progress.resignCurrent()
        self.progress.removeObserver(self, forKeyPath: keyPath, context: self.NVHProgressObserverContext)
    }
    
    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        if context == self.NVHProgressObserverContext {
            let _progress:NSProgress = object as! NSProgress;
            NSOperationQueue.mainQueue().addOperationWithBlock({
                if fmod(_progress.fractionCompleted * 100, 10.0) == 0 {
                    println(_progress.fractionCompleted)
                }
            })
        }
    }

    func alertView(alertView: UIAlertView, clickedButtonAtIndex buttonIndex: Int) {
        switch (buttonIndex) {
        case 1:
            self.tableView.setEditing(false, animated: true)
            break
        case 0:
            let path:NSURL = self.paths.datasetsSubdirectory(self.dataFolders[self.cellToDelete])
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
                NSFileManager.defaultManager().removeItemAtPath(path.absoluteString!, error: nil)
            })

            self.dataFolderSizes.removeValueForKey(self.dataFolders[self.cellToDelete])
            NSUserDefaults.standardUserDefaults().setObject(self.dataFolderSizes, forKey: "data-folder-sizes")

            self.dataFolders.removeAtIndex(self.cellToDelete)
            self.table.reloadData()

            if self.dataFolders.count == 0 {
                self.table.setEditing(false, animated: true)
            }

            break
        default:
            break
        }
        self.cellToDelete = -1
    }

    @IBAction func addDataset() {
        self.table.setEditing(false, animated: false)
    }

    @IBAction func showAboutPage() {
        let newController:AboutViewController = storyboard?.instantiateViewControllerWithIdentifier("AboutViewController") as! AboutViewController
        newController.title = "About"
        navigationController?.pushViewController(newController, animated: true)
    }

    func presentTonicView(viewTitle:String) {
        let newController = storyboard?.instantiateViewControllerWithIdentifier("TonicViewController") as! TonicViewController
        newController.title = viewTitle
        navigationController?.pushViewController(newController, animated: true)
    }

    func sizeForFolder(folderName:String) -> String {
        let folderPath:String = self.paths.datasetsSubdirectory(folderName).absoluteString!
        if !NSFileManager.defaultManager().fileExistsAtPath(folderPath) {
            return "unknown"
        }
        let contents:[String] = NSFileManager.defaultManager().subpathsOfDirectoryAtPath(folderPath, error: nil)! as! [String]
        var folderSize:UInt64 = 0

        for file:String in contents {
            let fDict:NSDictionary = NSFileManager.defaultManager().attributesOfItemAtPath(
                folderPath + "/" + file, error: nil)!
            folderSize += fDict.fileSize()
        }
        return NSByteCountFormatter.stringFromByteCount(Int64(folderSize), countStyle: NSByteCountFormatterCountStyle.File)
    }

    func isDirectory(path:String) -> Bool {
        var isDir:ObjCBool = false
        let exists = NSFileManager.defaultManager().fileExistsAtPath(path, isDirectory: &isDir)
        return isDir.boolValue
    }
}
