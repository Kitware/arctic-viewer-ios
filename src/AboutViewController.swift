//
//  AboutViewController.swift
//  ArcticViewer
//
//  Created by Tristan on 7/24/15.
//  Copyright (c) 2015 Kitware. All rights reserved.
//

import UIKit

class AboutViewController: UIViewController,
    UIImagePickerControllerDelegate, UIPickerViewDataSource, UITextFieldDelegate {

    @IBOutlet weak var downloadButton: UIButton!
    @IBOutlet weak var versionInput: ARDownloadInput!
    @IBOutlet weak var pickerContainer: UIView!
    @IBOutlet weak var picker: UIPickerView!
    @IBOutlet weak var doneButton: UIBarButtonItem!
    @IBOutlet weak var refreshButton: UIBarButtonItem!
    @IBOutlet weak var pickerContainerBottomConstraint: NSLayoutConstraint!

    var pickerOpen:Bool = false
    var versions:[String] = [String]()
    var currentVersion:String = NSUserDefaults.standardUserDefaults().stringForKey("arctic-web-version")!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.versionInput.text = self.currentVersion
        if let tags:[String] = NSUserDefaults.standardUserDefaults().arrayForKey("arctic-web-tags") as? [String] {
            self.versions = tags
            self.versions.insert("master", atIndex: 0)
            self.picker.reloadAllComponents()
        }

        let firstFetch:Bool = NSUserDefaults.standardUserDefaults().boolForKey("first-start-version-fetching")
        if !firstFetch {
            self.fetchVersions()
            NSUserDefaults.standardUserDefaults().setBool(true, forKey: "first-start-version-fetching")
        }
    }

    override func viewWillDisappear(animated: Bool) {
        NSUserDefaults.standardUserDefaults().synchronize()
    }

    @IBAction func refreshPressed(sender: AnyObject) {
        self.fetchVersions()
        self.refreshButton.enabled = false
    }

    // MARK: Fetching
    func fetchVersions() {
        let URL:NSURL = NSURL(string: "https://api.github.com/repos/Kitware/arctic-viewer/tags")!
        let sessionConfig = NSURLSessionConfiguration.defaultSessionConfiguration()
        let session = NSURLSession(configuration: sessionConfig, delegate: nil, delegateQueue: nil)
        let request:NSMutableURLRequest = NSMutableURLRequest(URL:URL)
        request.HTTPMethod = "GET"

        let task:NSURLSessionTask = session.dataTaskWithRequest(request,
            completionHandler: { (data: NSData!, response: NSURLResponse!, error: NSError!) -> Void in
                if error != nil {
                    return
                }

                let json:AnyObject? = NSJSONSerialization.JSONObjectWithData(data,
                    options: NSJSONReadingOptions.AllowFragments,
                    error:nil)

                self.versions = ["master"]
                if let parsedJSON = json as? NSArray {
                    for item in parsedJSON {
                        self.versions.append((item["name"] as! String))
                    }
                }

                NSUserDefaults.standardUserDefaults().setObject(self.versions, forKey: "arctic-web-tags")

                dispatch_async(dispatch_get_main_queue(), {
                    self.refreshButton.enabled = true
                    self.picker.reloadAllComponents()
                })
        })
        task.resume()
    }

    func textFieldShouldBeginEditing(textField: UITextField) -> Bool {
        self.showUIPicker()
        return false
    }

    // MARK: UIPickerView stuff
    func showUIPicker() {
        var indexOfCurrentVersion = 0
        for i:Int in 0..<self.versions.count {
            if self.versions[i] == self.currentVersion {
                indexOfCurrentVersion = i
                break
            }
        }
        self.picker.selectRow(indexOfCurrentVersion, inComponent: 0, animated: false)
        self.pickerOpen = true
        UIView.animateWithDuration(0.3, animations: {
            self.pickerContainerBottomConstraint.constant = 0.0
                self.pickerContainer.frame.origin = CGPointMake(0, self.view.frame.size.height - self.pickerContainer.frame.height)
        })
    }

    @IBAction func hidePickerView(sender: AnyObject) {
        self.pickerOpen = false
        UIView.animateWithDuration(0.3, animations: {
            self.pickerContainerBottomConstraint.constant = -self.pickerContainer.frame.size.height
            self.pickerContainer.frame.origin = CGPointMake(0, self.view.frame.size.height)
        })
    }

    func pickerView(pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        self.versionInput.text = self.versions[row]
    }

    func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String! {
        return self.versions[row]
    }

    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return self.versions.count
    }

    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return 1
    }

    // MARK: Downloading
    @IBAction func downloadPressed(sender: AnyObject) {
        if count(versionInput.text) == 0 {
            return
        }

        if self.pickerOpen {
            self.hidePickerView(Int())
        }

        self.downloadButton.hidden = true
        let spinner:UIActivityIndicatorView = UIActivityIndicatorView()
        spinner.color = UIColor(red: 0.209, green: 0.596, blue: 0.858, alpha: 1)
        spinner.frame = self.downloadButton.frame
        self.view.addSubview(spinner)
        spinner.startAnimating()

        let URL:NSURL = NSURL(string: "https://github.com/Kitware/arctic-viewer/archive/\(self.versionInput.text).tar.gz")!
        let sessionConfig = NSURLSessionConfiguration.defaultSessionConfiguration()
        let session = NSURLSession(configuration: sessionConfig, delegate: nil, delegateQueue: nil)
        let request:NSMutableURLRequest = NSMutableURLRequest(URL:URL)
        request.HTTPMethod = "GET"

        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        
        let task:NSURLSessionTask = session.dataTaskWithRequest(request,
            completionHandler: { (data: NSData!, response: NSURLResponse!, error: NSError!) -> Void in
                if error != nil {
                    dispatch_async(dispatch_get_main_queue(), {
                        let alert:UIAlertView = UIAlertView(title: "Problem Downloading New Version", message: "", delegate: nil, cancelButtonTitle: "Cancel", otherButtonTitles: "")
                        alert.show()
                    })
                    return
                }

                // deflate download.
                let manager:NSFileManager = NSFileManager.defaultManager()
                let sourceTgzPath:NSURL = Paths().tmpDirectory().URLByAppendingPathComponent("\(self.versionInput.text).tar.gz")
                manager.createFileAtPath(sourceTgzPath.path!, contents: data, attributes: nil)
                var error:NSError?
                NVHTarGzip.sharedInstance().unTarGzipFileAtPath(
                    sourceTgzPath.path!,
                    toPath: Paths().tmpDirectory().path!,
                    error: &error)

                // copy the items in the dist folder to web_content
                // this will not copy directories
                var trueVersion:String = "master"
                if self.versionInput.text != "master" {
                    trueVersion = self.versionInput.text.substringFromIndex(self.versionInput.text.startIndex.successor())
                }
                let versionDirectory:String = Paths().tmpDirectory().URLByAppendingPathComponent("arctic-viewer-\(trueVersion)").path!
                let distDirectory:String = versionDirectory + "/dist/"
                let files:[AnyObject] = manager.contentsOfDirectoryAtPath(distDirectory, error: nil)!
                for file:String in files as! [String] {
                    // delete the old folder to avoid overwrite
                    if manager.isDeletableFileAtPath(Paths().webcontentDirectory().path! + "/" + file) {
                        manager.removeItemAtPath(Paths().webcontentDirectory().path! + "/" + file, error: nil)
                    }
                    manager.copyItemAtPath(distDirectory + "/" + file, toPath: Paths().webcontentDirectory().path! + "/" + file, error: nil)
                }
                // remove the old downloads
                manager.removeItemAtPath(sourceTgzPath.path!, error: nil)
                manager.removeItemAtPath(versionDirectory, error: nil)

                // get rid of the spinner, show a checkmark for 1.5 seconds, reenable the download button
                dispatch_async(dispatch_get_main_queue(), {
                    UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                    spinner.removeFromSuperview()
                    self.downloadButton.setImage(
                        UIImage(named: "checkmark", inBundle: NSBundle.mainBundle(), compatibleWithTraitCollection: nil),
                        forState: UIControlState.Normal)
                    self.downloadButton.enabled = false
                    self.downloadButton.hidden = false

                    NSTimer.after(NSTimeInterval(1.5)){
                        self.downloadButton.setImage(
                            UIImage(named: "download", inBundle: NSBundle.mainBundle(),compatibleWithTraitCollection: nil),
                            forState: UIControlState.Normal)
                        self.downloadButton.enabled = true
                    }

                    self.currentVersion = self.versionInput.text
                    NSUserDefaults.standardUserDefaults().setValue(self.currentVersion, forKey: "arctic-web-version")
                    NSUserDefaults.standardUserDefaults().synchronize()
                })
        })
        task.resume()
    }
}
