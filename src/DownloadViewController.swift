//
//  DownloadViewController.swift
//  ArcticViewer
//
//  Created by Tristan on 7/15/15.
//  Copyright (c) 2015 Kitware. All rights reserved.
//

import UIKit

class DownloadViewController: UIViewController, UINavigationControllerDelegate, //View management
    UIAlertViewDelegate, UITextFieldDelegate, //Small UI delegates
    UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, // CollectionView delegates
    NSURLSessionDelegate, NSURLSessionDownloadDelegate, // Download delegates
    ARDownloadInstanceDelegate {

    @IBOutlet weak var urlInput: ARDownloadInput!
    @IBOutlet weak var downloadButton: UIButton!

    @IBOutlet weak var grid: UICollectionView!

    let paths:Paths = Paths()
    var folderMetaData:[String:String]!
    var downloadInstance:ARDownloadInstance = ARDownloadInstance.sharedInstance

    var downloadTask:NSURLSessionDownloadTask!
    var contents:[AnyObject] = []
    var fileName:String = ""
    var fileTitle:String = ""
    var downloading:Bool = false
    var selectedCell:NSIndexPath?

    override func viewDidLoad() {
        super.viewDidLoad()

        self.folderMetaData = NSUserDefaults.standardUserDefaults().dictionaryForKey("data-folder-sizes") as! [String:String]

        //load json here
        let data:NSData = NSFileManager.defaultManager().contentsAtPath(paths.webcontentDirectory().URLByAppendingPathComponent("sample-data.json").absoluteString!)!

        let json:AnyObject? = NSJSONSerialization.JSONObjectWithData(data,
            options: NSJSONReadingOptions.AllowFragments,
            error:nil)

        if let parsedJSON = json as? NSArray {
            for item in parsedJSON {
                contents.append(item)
            }
        }

        self.downloadInstance.delegate = self
        if self.downloadInstance.downloadTitle != "" {
            self.uiLock(true)
            self.urlInput.text = self.downloadInstance.downloadTitle
            self.downloadTask = self.downloadInstance.downloadTask
        }
    }

    override func viewWillDisappear(animated: Bool) {
        NSUserDefaults.standardUserDefaults().synchronize()
    }

    @IBAction func done() {
        urlInput.resignFirstResponder()
        self.dismissViewControllerAnimated(true, completion: nil)
    }

    @IBAction func downloadPressed(sender: AnyObject) {

        self.urlInput.resignFirstResponder()

        var text:String = urlInput.text
        if self.selectedCell != nil {
            text = (self.grid.cellForItemAtIndexPath(self.selectedCell!) as! DownloadViewCell).url
        }

        if count(text) == 0 {
            return
        }
        else if ![".zip", ".tar", ".tgz", ".tar.gz", ".gz"].some({ ext in
            return text.hasSuffix(ext)
        }) {
            let ext:String = text.componentsSeparatedByString(".").last!
            let alert:UIAlertView = UIAlertView(title: "File Format Not Supported", message: ".\(ext) is not supported by Arctic.", delegate: nil, cancelButtonTitle: "Cancel")
            alert.show()
            return
        }

        if let URL = NSURL(string:text) {
            self.fileName = text.componentsSeparatedByString("/").last!
            self.fileTitle = self.fileName.componentsSeparatedByString(".").first!
            self.uiLock(true)
            self.check(URL, loadCallback: self.load)
        }
    }

    func cancelPressed(sender:AnyObject) {
        if self.downloadTask != nil {
            let alert:UIAlertView = UIAlertView(title: "Stop download?", message: "Stop downloading \(self.fileName)?", delegate: self, cancelButtonTitle: "Stop", otherButtonTitles: "Continue")
            alert.show()
        }
    }

    func progressUpdated(progress:Float) {
        dispatch_async(dispatch_get_main_queue(), {
            self.urlInput.progress = progress
        })
    }

    //MARK: TextField Delegate
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }

    func textFieldDidBeginEditing(textField: UITextField) {
        if self.selectedCell != nil {
            self.urlInput.text = (self.grid.cellForItemAtIndexPath(self.selectedCell!) as! DownloadViewCell).url
        }
    }

    func textFieldDidEndEditing(textField: UITextField) {
        if self.selectedCell != nil {
            if self.urlInput.text == (self.grid.cellForItemAtIndexPath(self.selectedCell!) as! DownloadViewCell).url {
                var title:String = self.contents[self.selectedCell!.row]["title"] as! String
                if let size:AnyObject = self.contents[self.selectedCell!.row]["filesize"] {
                    title += ": \(size as! String)"
                }
                self.urlInput.text = title
                return
            }
            else {
                self.grid.deselectItemAtIndexPath(self.selectedCell!, animated: false)
                self.selectedCell = nil
            }
        }
    }

    func textFieldShouldClear(textField: UITextField) -> Bool {
        if selectedCell != nil {
            self.grid.deselectItemAtIndexPath(self.selectedCell, animated: false)
            self.selectedCell = nil
        }
        return true
    }

    //MARK: UICollection Delegate
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell:DownloadViewCell = self.grid.dequeueReusableCellWithReuseIdentifier("cell", forIndexPath: indexPath) as! DownloadViewCell

        let title:String = self.contents[indexPath.row]["title"] as! String

        var urlFile:String = self.contents[indexPath.row]["url"] as! String
        cell.url = urlFile

        urlFile = urlFile.componentsSeparatedByString("/").last!.componentsSeparatedByString(".").first!
        if contains(self.folderMetaData.keys.array, urlFile) {
            cell.downloadedTag?.image = UIImage(named: "downloaded-tag", inBundle: NSBundle.mainBundle(), compatibleWithTraitCollection: nil)
            cell.downloadedTag?.hidden = false
        }
        else {
            cell.downloadedTag?.hidden = true
        }

        if let thumbURL:NSURL = NSURL(string: self.contents[indexPath.row]["thumbnail"] as! String) {
            let block: SDWebImageCompletionBlock! = {(image: UIImage!, error: NSError!, cacheType: SDImageCacheType, imageURL: NSURL!) -> () in
                if image != nil {
                    var dataFolderThumbs:[String:String] = NSUserDefaults.standardUserDefaults().objectForKey("data-folder-thumbs") as! [String:String]
                    dataFolderThumbs[urlFile] = imageURL.description
                    NSUserDefaults.standardUserDefaults().setObject(dataFolderThumbs, forKey: "data-folder-thumbs")
                    cell.thumbnail?.image = image
                }
                else {
                    cell.thumbnail?.image = UIImage(named: "null-image", inBundle: NSBundle.mainBundle(), compatibleWithTraitCollection: nil)
                }
            }
            cell.thumbnail?.sd_setImageWithURL(thumbURL, completed:block)
        }
        else {
            cell.thumbnail?.image = UIImage(named: "null-image", inBundle: NSBundle.mainBundle(), compatibleWithTraitCollection: nil)
        }

        return cell
    }

    func collectionView(collectionView: UICollectionView, shouldSelectItemAtIndexPath indexPath: NSIndexPath) -> Bool {
        if self.downloading {
            return false
        }

        if self.selectedCell == indexPath {
            self.grid.deselectItemAtIndexPath(indexPath, animated: false)
            self.selectedCell = nil
            self.urlInput.text = ""
            return false
        }

        if self.selectedCell != nil {
            self.grid.deselectItemAtIndexPath(self.selectedCell!, animated: false)
        }
        self.selectedCell = indexPath

        self.urlInput.resignFirstResponder()
        var title:String = self.contents[indexPath.row]["title"] as! String
        if let size:AnyObject = self.contents[indexPath.row]["filesize"] {
            title += ": \(size as! String)"
        }
        self.urlInput.text = title
        return true
    }

    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.contents.count
    }

    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
            return CGSize(width: 220, height: 220)
        }
        else if UIScreen.mainScreen().bounds.size.height == 667.0 { //iPhone 6
            return CGSize(width: 165, height: 165)
        }
        else if UIScreen.mainScreen().bounds.size.height == 736.0 { //iPhone 6+
            return CGSize(width: 180, height: 180)
        }
        else {
            return CGSize(width: 138, height: 138)
        }
    }

    // MARK: URLSession methods
    func check(URL:NSURL, loadCallback:(NSURL)->()) {
        // Check if Wifi enabled before downloading anything
        if !isWifiOn() {
            let alert:UIAlertView = UIAlertView(title: "Unable to download data", message: "You need to turn the Wifi ON.", delegate: nil, cancelButtonTitle: "OK")
            alert.show()
            self.uiLock(false)
            return
        }

        // check if location exists
        let sessionConfig = NSURLSessionConfiguration.defaultSessionConfiguration()
        let session = NSURLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil)
        let request:NSMutableURLRequest = NSMutableURLRequest(URL: URL)
        request.HTTPMethod = "HEAD"

        let task:NSURLSessionTask = session.dataTaskWithRequest(request,
            completionHandler: { (data: NSData!, response: NSURLResponse!, error: NSError!) -> Void in

                if (response as! NSHTTPURLResponse).statusCode != 200 {
                    dispatch_async(dispatch_get_main_queue(), {
                        let alert:UIAlertView = UIAlertView(title: "Invalid URL", message: "", delegate: self, cancelButtonTitle: "Cancel")
                        alert.show()
                    })
                    return
                }

                if let freespace = self.deviceRemainingFreeSpaceInBytes() {
                    let requiredSpace:String = NSByteCountFormatter.stringFromByteCount(
                        response.expectedContentLength,
                        countStyle: NSByteCountFormatterCountStyle.File)
                    self.folderMetaData[self.fileTitle] = requiredSpace
                    NSUserDefaults.standardUserDefaults().setObject(self.folderMetaData, forKey: "data-folder-sizes")
                    NSUserDefaults.standardUserDefaults().synchronize()
                    if freespace <= response.expectedContentLength {
                        dispatch_async(dispatch_get_main_queue(), {
                            let alert:UIAlertView = UIAlertView(title: "Insufficient Space", message: "\(requiredSpace) needed to download this file.", delegate: self, cancelButtonTitle: "Cancel")
                            alert.show()
                        })
                        return
                    }
                }
                loadCallback(URL)
        })
        task.resume()
    }

    func load(URL: NSURL) {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        let sessionConfig:NSURLSessionConfiguration = NSURLSessionConfiguration.defaultSessionConfiguration()
        let session:NSURLSession = NSURLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil)
        self.downloadTask = session.downloadTaskWithURL(URL)
        self.downloadTask.resume()

        self.downloadInstance.downloadTitle = URL.absoluteString!.componentsSeparatedByString("/").last!
        self.downloadInstance.downloadTask = self.downloadTask
    }

    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress:Float = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
        self.downloadInstance.progress = progress
//        dispatch_async(dispatch_get_main_queue(), {
////            let nom:String = NSByteCountFormatter.stringFromByteCount(totalBytesWritten, countStyle: NSByteCountFormatterCountStyle.File)
////            let denom:String = NSByteCountFormatter.stringFromByteCount(totalBytesExpectedToWrite, countStyle: NSByteCountFormatterCountStyle.File)
////            self.statusLabel.text = "\(nom)/\(denom)"
//            self.urlInput.progress = progress
//        })
    }

    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL) {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        if self.fileName.hasSuffix(".zip") {
            println("un-zipping")
            let path:NSURL = self.paths.datasetsSubdirectory(self.fileName)
            self.unZip(location)
        }
        else if self.fileName.hasSuffix(".tar.gz") || self.fileName.hasSuffix(".tgz") {
            println("un-gzipping, un-taring")
            self.unTgz(location)
        }
        else if self.fileName.hasSuffix(".gz") {
            println("un-gzipping")
            let path:NSURL = self.paths.datasetsSubdirectory(self.fileName)
            self.unGzip(location)
        }
        else if self.fileName.hasSuffix(".tar") {
            println("un-taring")
            self.unTar(location)
        }
        else {
            println("unrecognized extension")
        }

        dispatch_async(dispatch_get_main_queue(), {
            self.uiLock(false)
            self.downloadInstance.downloadTitle = ""
            self.downloadInstance.downloadTask = nil
            self.urlInput.text = ""
            let cell:DownloadViewCell = self.grid.cellForItemAtIndexPath(self.selectedCell!) as! DownloadViewCell
            cell.downloadedTag?.image = UIImage(named: "downloaded-tag", inBundle: NSBundle.mainBundle(), compatibleWithTraitCollection: nil)
            cell.downloadedTag?.hidden = false
        })
    }

    // MARK: decompression

    // TODO: This method is untested!
    func unZip(zipPath:NSURL) {
        let manager:NSFileManager = NSFileManager.defaultManager()
        let newZipPath:String = zipPath.absoluteString!.componentsSeparatedByString("/").last!.componentsSeparatedByString(".").first! //drop the .zip
        let destinationPath:NSURL = self.paths.datasetsSubdirectory("/datasets/" + newZipPath)
        SSZipArchive.unzipFileAtPath(zipPath.absoluteString!, toDestination: destinationPath.absoluteString!)
        manager.removeItemAtURL(zipPath, error: nil)
    }

    func unGzip(location:NSURL) {
        let path:NSURL = self.paths.datasetsDirectory()
        var error:NSError?
        NVHTarGzip.sharedInstance().unGzipFileAtPath(location.path!, toPath: path.path, error: &error)
    }

    func unTar(location:NSURL) {
        let path:NSURL = self.paths.datasetsDirectory()
        var error:NSError?
        NVHTarGzip.sharedInstance().unTarFileAtPath(location.path!, toPath: path.path!, error: &error)
    }

    func unTgz(location:NSURL) {
        let path:NSURL = self.paths.datasetsDirectory()
        var error:NSError?
        NVHTarGzip.sharedInstance().unTarGzipFileAtPath(location.path!, toPath: path.path!, error: &error)
    }

    // MARK: misc
    func alertView(alertView: UIAlertView, clickedButtonAtIndex buttonIndex: Int) {
        if alertView.title == "Stop download?" {
            if buttonIndex == 0 {
                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                self.downloadTask.cancel()
                self.uiLock(false)
            }
        }
        else {
            self.uiLock(false)
        }
    }

    func uiLock(val:Bool) {
        self.downloading = val
        self.urlInput.enabled = !val
        dispatch_async(dispatch_get_main_queue(), {
            self.urlInput.progress = 0.0
        })

        UIApplication.sharedApplication().idleTimerDisabled = val
        
        if val {
            self.downloadButton.removeTarget(self, action: Selector("downloadPressed:"), forControlEvents: UIControlEvents.TouchUpInside)
            self.downloadButton.addTarget(self, action: Selector("cancelPressed:"), forControlEvents: UIControlEvents.TouchUpInside)
            self.downloadButton.setImage(UIImage(named: "cancel", inBundle: NSBundle.mainBundle(), compatibleWithTraitCollection: nil),
                forState: UIControlState.Normal)
        }
        else {
            self.downloadButton.removeTarget(self, action: Selector("cancelPressed:"), forControlEvents: UIControlEvents.TouchUpInside)
            self.downloadButton.addTarget(self, action: Selector("downloadPressed:"), forControlEvents: UIControlEvents.TouchUpInside)
            self.downloadButton.setImage(UIImage(named: "download", inBundle: NSBundle.mainBundle(), compatibleWithTraitCollection: nil),
                forState: UIControlState.Normal)
        }
    }

    func deviceRemainingFreeSpaceInBytes() -> Int64? {
        let documentDirectoryPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
        if let systemAttributes = NSFileManager.defaultManager().attributesOfFileSystemForPath(documentDirectoryPath.last as! String, error: nil) {
            if let freeSize = systemAttributes[NSFileSystemFreeSize] as? NSNumber {
                return freeSize.longLongValue
            }
        }
        // something failed
        return nil
    }
}
