//
//  AboutViewController.swift
//  ArcticViewer
//
//  Created by Tristan on 7/24/15.
//  Copyright (c) 2015 Kitware. All rights reserved.
//

import UIKit
import NVHTarGzip

class AboutViewController: UIViewController,
    UIImagePickerControllerDelegate, UIPickerViewDataSource, UITextFieldDelegate {

    @IBOutlet weak var kwSubtitle: UILabel!
    @IBOutlet weak var downloadButton: UIButton!
    @IBOutlet weak var versionInput: ARDownloadInput!
    @IBOutlet weak var pickerContainer: UIView!
    @IBOutlet weak var picker: UIPickerView!
    @IBOutlet weak var doneButton: UIBarButtonItem!
    @IBOutlet weak var refreshButton: UIBarButtonItem!
    @IBOutlet weak var pickerContainerBottomConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var lensSwitch: UISwitch!
    @IBOutlet weak var singleViewSwitch: UISwitch!

    var pickerOpen:Bool = false
    var versions:[String] = [String]()
    var currentVersion:String = UserDefaults.standard.string(forKey: "arctic-web-version")!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.versionInput.text = self.currentVersion
        if let tags:[String] = UserDefaults.standard.array(forKey: "arctic-web-tags") as? [String] {
            self.versions = tags
            self.picker.reloadAllComponents()
        }

        let firstFetch:Bool = UserDefaults.standard.bool(forKey: "first-start-version-fetching")
        if !firstFetch {
            self.fetchVersions()
            UserDefaults.standard.set(true, forKey: "first-start-version-fetching")
        }

        if let version:String = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as? String {
            self.kwSubtitle.text = "v\(version)  " + self.kwSubtitle.text!
        }

        self.setupSwitches()
    }

    override func viewWillDisappear(_ animated: Bool) {
        UserDefaults.standard.synchronize()
    }

    @IBAction func refreshPressed(_ sender: AnyObject) {
        self.fetchVersions()
        self.refreshButton.isEnabled = false
    }

    func parseJson(_ data:Data) -> [String:AnyObject]? {
        var json:Any?
        do {
            try json = JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments)
        } catch {
            print((error as NSError).localizedDescription)
            return nil
        }

        guard let parsedJSON:[String:AnyObject] = json as? [String:AnyObject] else {
            return nil
        }

        return parsedJSON
    }

    // MARK: Fetching
    func fetchVersions() {
        let URL:Foundation.URL = Foundation.URL(string: "https://api.github.com/repos/Kitware/arctic-viewer/tags")!
        let sessionConfig = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfig, delegate: nil, delegateQueue: nil)
        var request:URLRequest = URLRequest(url:URL)
        request.httpMethod = "GET"

        let task:URLSessionTask = session.dataTask(with: request,
            completionHandler: { (data: Data?, response: URLResponse?, error: Error?) -> Void in
                if error != nil {
                    return
                }

                var json:Any?
                do {
                    try json = JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.allowFragments)
                } catch {
                    print((error as NSError).localizedDescription)
                }

                self.versions = ["master"]
                if let parsedJSON = json as? [[String: Any]] {
                    for item in parsedJSON {
                        self.versions.append(item["name"] as! String)
                    }
                }

                UserDefaults.standard.set(self.versions, forKey: "arctic-web-tags")

                DispatchQueue.main.async(execute: {
                    self.refreshButton.isEnabled = true
                    self.picker.reloadAllComponents()
                })
        })
        task.resume()
    }

    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
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
        UIView.animate(withDuration: 0.3, animations: {
            self.pickerContainerBottomConstraint.constant = 0.0
                self.pickerContainer.frame.origin = CGPoint(x: 0, y: self.view.frame.size.height - self.pickerContainer.frame.height)
        })
    }

    @IBAction func hidePickerView(_ sender: AnyObject) {
        self.pickerOpen = false
        UIView.animate(withDuration: 0.3, animations: {
            self.pickerContainerBottomConstraint.constant = -self.pickerContainer.frame.size.height
            self.pickerContainer.frame.origin = CGPoint(x: 0, y: self.view.frame.size.height)
        })
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        self.versionInput.text = self.versions[row]
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String! {
        return self.versions[row]
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return self.versions.count
    }

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    // MARK: config.json settings and switches
    @IBAction func switchDidChange(_ sender:AnyObject) {
        switch (sender as! UISwitch) {
        case let x where x == self.lensSwitch:
            self.configSwitch("MagicLens", newVal: self.lensSwitch.isOn)
            break
        case let x where x == self.singleViewSwitch:
            self.configSwitch("SingleView", newVal: self.singleViewSwitch.isOn)
            break
        default:
            break
        }
    }

    func setupSwitches() {
        let configPath:String = Paths().webcontentDirectory().path + "/config.json"

        if let parsedJSON:[String:AnyObject] = self.parseJson(try! Data(contentsOf: URL(fileURLWithPath: configPath))) {
            self.lensSwitch.setOn(parsedJSON["MagicLens"] as! Bool, animated: false)
            self.singleViewSwitch.setOn(parsedJSON["SingleView"] as! Bool, animated: false)
        }
    }

    func configSwitch(_ attr:String, newVal:Bool) {
        //open config.json
        let configPath:String = Paths().webcontentDirectory().path + "/config.json"
        guard var parsedJSON:[String:AnyObject] = self.parseJson(try! Data(contentsOf: URL(fileURLWithPath: configPath))) else {
            print("could not parse JSON")
            return
        }
        //write new attribute value
        parsedJSON[attr] = newVal as AnyObject?

        //save it
        let stream:OutputStream = OutputStream(toFileAtPath: configPath, append: false)!
        stream.open()
        JSONSerialization.writeJSONObject(parsedJSON,
            to: stream,
            options: JSONSerialization.WritingOptions(), error: nil)
        stream.close()
    }

    // MARK: Downloading
    @IBAction func downloadPressed(_ sender: AnyObject) {
        if versionInput.text?.characters.count == 0 {
            return
        }

        if self.pickerOpen {
            self.hidePickerView(Int() as AnyObject)
        }

        self.downloadButton.isHidden = true
        let spinner:UIActivityIndicatorView = UIActivityIndicatorView()
        spinner.color = UIColor(red: 0.209, green: 0.596, blue: 0.858, alpha: 1)
        spinner.frame = self.downloadButton.frame
        self.view.addSubview(spinner)
        spinner.startAnimating()

        let URL:Foundation.URL = Foundation.URL(string: "https://github.com/Kitware/arctic-viewer/archive/\(self.versionInput.text!).tar.gz")!
        let sessionConfig = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfig, delegate: nil, delegateQueue: nil)
        var request:URLRequest = URLRequest(url:URL)
        request.httpMethod = "GET"

        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        let task:URLSessionTask = session.dataTask(with: request,
            completionHandler: { (data:Data?, response:URLResponse?, error:Error?) -> Void in
                if error != nil {
                    DispatchQueue.main.async(execute: {
                        let alert:UIAlertView = UIAlertView(title: "Problem Downloading New Version", message: "", delegate: nil, cancelButtonTitle: "Cancel", otherButtonTitles: "")
                        alert.show()
                    })
                    return
                }

                // deflate download.
                let manager:FileManager = FileManager.default
                let sourceTgzPath:Foundation.URL = Paths().tmpDirectory().appendingPathComponent("\(self.versionInput.text).tar.gz")
                manager.createFile(atPath: sourceTgzPath.path, contents: data, attributes: nil)
                try! NVHTarGzip.sharedInstance().unTarGzipFile(
                    atPath: sourceTgzPath.path,
                    toPath: Paths().tmpDirectory().path)

                // copy the items in the dist folder to web_content
                // this will not copy directories
                var trueVersion:String = "master"
                if self.versionInput.text != "master" {
                    trueVersion = self.versionInput.text!.substring(from: self.versionInput.text!.characters.index(after: self.versionInput.text!.startIndex))
                }
                let versionDirectory:String = Paths().tmpDirectory().appendingPathComponent("arctic-viewer-\(trueVersion)").path
                let distDirectory:String = versionDirectory + "/dist/"
                let files:[AnyObject] = try! manager.contentsOfDirectory(atPath: distDirectory) as [AnyObject]
                for file:String in files as! [String] {
                    // delete the old folder to avoid overwrite
                    let filePath:String = Paths().webcontentDirectory().path + "/" + file
                    if manager.fileExists(atPath: filePath) && manager.isDeletableFile(atPath: filePath) {
                        do {
                            try manager.removeItem(atPath: filePath)
                        } catch {
                            print("problem deleting at \(filePath)")
                        }
                    }
                    try! manager.copyItem(atPath: distDirectory + "/" + file, toPath: filePath)
                }
                // remove the old downloads
                try! manager.removeItem(atPath: sourceTgzPath.path)
                try! manager.removeItem(atPath: versionDirectory)

                // get rid of the spinner, show a checkmark for 1.5 seconds, reenable the download button
                DispatchQueue.main.async(execute: {
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                    spinner.removeFromSuperview()
                    self.downloadButton.setImage(
                        UIImage(named: "checkmark", in: Bundle.main, compatibleWith: nil),
                        for: UIControlState())
                    self.downloadButton.isEnabled = false
                    self.downloadButton.isHidden = false

                    let _ = Timer.after(TimeInterval(1.5)){
                        self.downloadButton.setImage(
                            UIImage(named: "download", in: Bundle.main,compatibleWith: nil),
                            for: UIControlState())
                        self.downloadButton.isEnabled = true
                    }

                    self.currentVersion = self.versionInput.text!
                    UserDefaults.standard.setValue(self.currentVersion, forKey: "arctic-web-version")
                    UserDefaults.standard.synchronize()
                })
        })
        task.resume()
    }
}
