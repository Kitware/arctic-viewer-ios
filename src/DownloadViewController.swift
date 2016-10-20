//
//  DownloadViewController.swift
//  ArcticViewer
//
//  Created by Tristan on 7/15/15.
//  Copyright (c) 2015 Kitware. All rights reserved.
//

import UIKit
import SSZipArchive
import NVHTarGzip
import SDWebImage

class DownloadViewController: UIViewController, UINavigationControllerDelegate, //View management
    UIAlertViewDelegate, UITextFieldDelegate, //Small UI delegates
    UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, // CollectionView delegates
    URLSessionDelegate, URLSessionDownloadDelegate, // Download delegates
    ARDownloadInstanceDelegate {

    @IBOutlet weak var urlInput: ARDownloadInput!
    @IBOutlet weak var downloadButton: UIButton!

    @IBOutlet weak var grid: UICollectionView!

    let paths:Paths = Paths()
    var folderMetaData:[String:String]!
    var downloadInstance:ARDownloadInstance = ARDownloadInstance.sharedInstance

    var downloadTask:URLSessionDownloadTask!
    var contents:[[String: Any]] = []
    var fileName:String = ""
    var fileTitle:String = ""
    var downloading:Bool = false
    var selectedCell:IndexPath?

    override func viewDidLoad() {
        super.viewDidLoad()

        self.folderMetaData = UserDefaults.standard.dictionary(forKey: "data-folder-sizes") as! [String:String]

        //load json here
        let data:Data = FileManager.default.contents(atPath: paths.webcontentDirectory().appendingPathComponent("sample-data.json").absoluteString)!

        let json:AnyObject? = try! JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments) as AnyObject?

        if let parsedJSON = json as? [[String: Any]] {
            for item in parsedJSON {
                contents.append(item as [String: Any])
            }
        }

        self.downloadInstance.delegate = self
        if self.downloadInstance.downloadTitle != "" {
            self.uiLock(true)
            self.urlInput.text = self.downloadInstance.downloadTitle
            self.downloadTask = self.downloadInstance.downloadTask
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        UserDefaults.standard.synchronize()
    }

    @IBAction func done() {
        urlInput.resignFirstResponder()
        self.dismiss(animated: true, completion: nil)
    }

    @IBAction func downloadPressed(_ sender: AnyObject) {

        self.urlInput.resignFirstResponder()

        var text:String = urlInput.text!
        if self.selectedCell != nil {
            text = (self.grid.cellForItem(at: self.selectedCell!) as! DownloadViewCell).url
        }

        if text.characters.count == 0 {
            return
        }
        else if ![".zip", ".tar", ".tgz", ".tar.gz", ".gz"].some({ ext in
            return text.hasSuffix(ext)
        }) {
            let ext:String = text.components(separatedBy: ".").last!
            let alert:UIAlertView = UIAlertView(title: "File Format Not Supported", message: ".\(ext) is not supported by Arctic.", delegate: nil, cancelButtonTitle: "Cancel")
            alert.show()
            return
        }

        if let URL = URL(string:text) {
            self.fileName = text.components(separatedBy: "/").last!
            self.fileTitle = self.fileName.components(separatedBy: ".").first!
            self.uiLock(true)
            self.check(URL, loadCallback: self.load)
        }
    }

    func cancelPressed(_ sender:AnyObject) {
        if self.downloadTask != nil {
            let alert:UIAlertView = UIAlertView(title: "Stop download?", message: "Stop downloading \(self.fileName)?", delegate: self, cancelButtonTitle: "Stop", otherButtonTitles: "Continue")
            alert.show()
        }
    }

    func progressUpdated(_ progress:Float) {
        DispatchQueue.main.async(execute: {
            self.urlInput.progress = progress
        })
    }

    //MARK: TextField Delegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        if self.selectedCell != nil {
            self.urlInput.text = (self.grid.cellForItem(at: self.selectedCell!) as! DownloadViewCell).url
        }
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if self.selectedCell != nil {
            if self.urlInput.text == (self.grid.cellForItem(at: self.selectedCell!) as! DownloadViewCell).url {
                var title:String = self.contents[(self.selectedCell! as IndexPath).row]["title"] as! String
                if let size:Any = self.contents[(self.selectedCell! as IndexPath).row]["filesize"] {
                    title += ": \(size as! String)"
                }
                self.urlInput.text = title
                return
            }
            else {
                self.grid.deselectItem(at: self.selectedCell!, animated: false)
                self.selectedCell = nil
            }
        }
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        if selectedCell != nil {
            self.grid.deselectItem(at: self.selectedCell!, animated: false)
            self.selectedCell = nil
        }
        return true
    }

    //MARK: UICollection Delegate
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell:DownloadViewCell = self.grid.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! DownloadViewCell

        var urlFile:String = self.contents[(indexPath as NSIndexPath).row]["url"] as! String
        cell.url = urlFile

        urlFile = urlFile.components(separatedBy: "/").last!.components(separatedBy: ".").first!
        if self.folderMetaData.keys.contains(urlFile) {
            cell.downloadedTag?.image = UIImage(named: "downloaded-tag", in: Bundle.main, compatibleWith: nil)
            cell.downloadedTag?.isHidden = false
        }
        else {
            cell.downloadedTag?.isHidden = true
        }

        if let thumbURL:URL = URL(string: self.contents[(indexPath as NSIndexPath).row]["thumbnail"] as! String) {
            let block: SDWebImageCompletionBlock! = {(image, error, cacheType, imageURL) -> () in
                if image != nil {
                    var dataFolderThumbs:[String:String] = UserDefaults.standard.object(forKey: "data-folder-thumbs") as! [String:String]
                    dataFolderThumbs[urlFile] = imageURL?.description
                    UserDefaults.standard.set(dataFolderThumbs, forKey: "data-folder-thumbs")
                    cell.thumbnail?.image = image
                }
                else {
                    cell.thumbnail?.image = UIImage(named: "null-image", in: Bundle.main, compatibleWith: nil)
                }
            }
            cell.thumbnail?.sd_setImage(with: thumbURL, completed:block)
        }
        else {
            cell.thumbnail?.image = UIImage(named: "null-image", in: Bundle.main, compatibleWith: nil)
        }

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        if self.downloading {
            return false
        }

        if self.selectedCell == indexPath {
            self.grid.deselectItem(at: indexPath, animated: false)
            self.selectedCell = nil
            self.urlInput.text = ""
            return false
        }

        if self.selectedCell != nil {
            self.grid.deselectItem(at: self.selectedCell!, animated: false)
        }
        self.selectedCell = indexPath

        self.urlInput.resignFirstResponder()
        var title:String = self.contents[(indexPath as NSIndexPath).row]["title"] as! String
        if let size:Any = self.contents[(indexPath as NSIndexPath).row]["filesize"] {
            title += ": \(size as! String)"
        }
        self.urlInput.text = title
        return true
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.contents.count
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return CGSize(width: 220, height: 220)
        }
        else if UIScreen.main.bounds.size.height == 667.0 { //iPhone 6
            return CGSize(width: 165, height: 165)
        }
        else if UIScreen.main.bounds.size.height == 736.0 { //iPhone 6+
            return CGSize(width: 180, height: 180)
        }
        else {
            return CGSize(width: 138, height: 138)
        }
    }

    // MARK: URLSession methods
    func check(_ URL:Foundation.URL, loadCallback:@escaping (Foundation.URL)->()) {
        // Check if Wifi enabled before downloading anything
        if !isWifiOn() {
            let alert:UIAlertView = UIAlertView(title: "Unable to download data", message: "You need to turn the Wifi ON.", delegate: nil, cancelButtonTitle: "OK")
            alert.show()
            self.uiLock(false)
            return
        }

        // check if location exists
        let sessionConfig = URLSessionConfiguration.default
        let session = Foundation.URLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil)
        var request:URLRequest = URLRequest(url: URL)
        request.httpMethod = "HEAD"

        let task:URLSessionTask = session.dataTask(with: request,
            completionHandler: { (data:Data?, response:URLResponse?, error:Error?) -> Void in

                if (response as! HTTPURLResponse).statusCode != 200 {
                    DispatchQueue.main.async(execute: {
                        let alert:UIAlertView = UIAlertView(title: "Invalid URL", message: "", delegate: self, cancelButtonTitle: "Cancel")
                        alert.show()
                    })
                    return
                }

                if let freespace = self.deviceRemainingFreeSpaceInBytes() {
                    let requiredSpace:String = ByteCountFormatter.string(
                        fromByteCount: response!.expectedContentLength,
                        countStyle: ByteCountFormatter.CountStyle.file)
                    self.folderMetaData[self.fileTitle] = requiredSpace
                    UserDefaults.standard.set(self.folderMetaData, forKey: "data-folder-sizes")
                    UserDefaults.standard.synchronize()
                    if freespace <= response!.expectedContentLength {
                        DispatchQueue.main.async(execute: {
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

    func load(_ URL: Foundation.URL) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        let sessionConfig:URLSessionConfiguration = URLSessionConfiguration.default
        let session:Foundation.URLSession = Foundation.URLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil)
        self.downloadTask = session.downloadTask(with: URL)
        self.downloadTask.resume()

        self.downloadInstance.downloadTitle = URL.absoluteString.components(separatedBy: "/").last!
        self.downloadInstance.downloadTask = self.downloadTask
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress:Float = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
        self.downloadInstance.progress = progress
//        dispatch_async(dispatch_get_main_queue(), {
////            let nom:String = NSByteCountFormatter.stringFromByteCount(totalBytesWritten, countStyle: NSByteCountFormatterCountStyle.File)
////            let denom:String = NSByteCountFormatter.stringFromByteCount(totalBytesExpectedToWrite, countStyle: NSByteCountFormatterCountStyle.File)
////            self.statusLabel.text = "\(nom)/\(denom)"
//            self.urlInput.progress = progress
//        })
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
        if self.fileName.hasSuffix(".zip") {
            print("un-zipping")
            self.unZip(location)
        }
        else if self.fileName.hasSuffix(".tar.gz") || self.fileName.hasSuffix(".tgz") {
            print("un-gzipping, un-taring")
            do {
                try self.unTgz(location)
            } catch {
                print((error as NSError).localizedDescription)
            }
        }
        else if self.fileName.hasSuffix(".gz") {
            print("un-gzipping")
            do {
                try self.unGzip(location)
            } catch {
                print((error as NSError).localizedDescription)
            }
        }
        else if self.fileName.hasSuffix(".tar") {
            print("un-taring")
            do {
                try self.unTar(location)
            } catch {
                print((error as NSError).localizedDescription)
            }
        }
        else {
            print("unrecognized extension")
        }

        DispatchQueue.main.async(execute: {
            self.uiLock(false)
            self.downloadInstance.downloadTitle = ""
            self.downloadInstance.downloadTask = nil
            self.urlInput.text = ""
            if self.selectedCell != nil {
                let cell:DownloadViewCell = self.grid.cellForItem(at: self.selectedCell!) as! DownloadViewCell
                cell.downloadedTag?.image = UIImage(named: "downloaded-tag", in: Bundle.main, compatibleWith: nil)
                cell.downloadedTag?.isHidden = false
            }
        })
    }

    // MARK: decompression

    // TODO: This method is untested!
    func unZip(_ zipPath:URL) {
        let manager:FileManager = FileManager.default
        let newZipPath:String = zipPath.absoluteString.components(separatedBy: "/").last!.components(separatedBy: ".").first! //drop the .zip
        let destinationPath:URL = self.paths.datasetsSubdirectory("/datasets/" + newZipPath)
        SSZipArchive.unzipFile(atPath: zipPath.absoluteString, toDestination: destinationPath.absoluteString)
        try! manager.removeItem(at: zipPath)
    }

    func unGzip(_ location:URL) throws {
        let path:URL = self.paths.datasetsDirectory() as URL
        try NVHTarGzip.sharedInstance().unGzipFile(atPath: location.path, toPath: path.path)
    }

    func unTar(_ location:URL) throws {
        let path:URL = self.paths.datasetsDirectory() as URL
        try NVHTarGzip.sharedInstance().unTarFile(atPath: location.path, toPath: path.path)
    }

    func unTgz(_ location:URL) throws {
        let path:URL = self.paths.datasetsDirectory() as URL
        try NVHTarGzip.sharedInstance().unTarGzipFile(atPath: location.path, toPath: path.path)
    }

    // MARK: misc
    func alertView(_ alertView: UIAlertView, clickedButtonAt buttonIndex: Int) {
        if alertView.title == "Stop download?" {
            if buttonIndex == 0 {
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
                self.downloadTask.cancel()
                self.uiLock(false)
            }
        }
        else {
            self.uiLock(false)
        }
    }

    func uiLock(_ val:Bool) {
        self.downloading = val
        self.urlInput.isEnabled = !val
        DispatchQueue.main.async(execute: {
            self.urlInput.progress = 0.0
        })

        UIApplication.shared.isIdleTimerDisabled = val
        
        if val {
            self.downloadButton.removeTarget(self, action: #selector(DownloadViewController.downloadPressed(_:)), for: UIControlEvents.touchUpInside)
            self.downloadButton.addTarget(self, action: #selector(DownloadViewController.cancelPressed(_:)), for: UIControlEvents.touchUpInside)
            self.downloadButton.setImage(UIImage(named: "cancel", in: Bundle.main, compatibleWith: nil),
                for: UIControlState())
        }
        else {
            self.downloadButton.removeTarget(self, action: #selector(DownloadViewController.cancelPressed(_:)), for: UIControlEvents.touchUpInside)
            self.downloadButton.addTarget(self, action: #selector(DownloadViewController.downloadPressed(_:)), for: UIControlEvents.touchUpInside)
            self.downloadButton.setImage(UIImage(named: "download", in: Bundle.main, compatibleWith: nil),
                for: UIControlState())
        }
    }

    func deviceRemainingFreeSpaceInBytes() -> Int64? {
        let documentDirectoryPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        if let systemAttributes = try? FileManager.default.attributesOfFileSystem(forPath: documentDirectoryPath.last!) {
            if let freeSize = systemAttributes[FileAttributeKey.systemFreeSize] as? NSNumber {
                return freeSize.int64Value
            }
        }
        // something failed
        return nil
    }
}
