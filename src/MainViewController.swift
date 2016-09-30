//
//  MainViewController.swift
//  ArcticViewer
//
//  Created by Tristan on 7/14/15.
//  Copyright (c) 2015 Kitware. All rights reserved.
//

import UIKit
import NVHTarGzip

class MainViewController: UITableViewController, UINavigationControllerDelegate, UIAlertViewDelegate {

    let paths:Paths = Paths()
    let store:UserDefaults = UserDefaults.standard
    var progress:Progress!
    let NVHProgressObserverContext:UnsafeMutableRawPointer? = nil
    
    @IBOutlet var table: UITableView!
    var dataFolders:[String] = []
    var cellToDelete:Int = -1
    var dataFolderSizes:[String:String]!
    var dataFolderThumbs:[String:String]!
    var deflating:Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "Datasets"

        NotificationCenter.default.addObserver(self, selector: #selector(MainViewController.handleURL(_:)), name: NSNotification.Name(rawValue: "InboxFile"), object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let path:String = self.paths.datasetsDirectory().absoluteString
        self.dataFolders = try! (FileManager.default.contentsOfDirectory(atPath: path))
            .filter({ (obj:String) in
                if obj.hasSuffix(".tar.gz") || obj.hasSuffix(".tgz") {
                    //remove the extension so it doesn't defalting twice
                    let newName:String = obj.components(separatedBy: ".").first!
                    if let url:URL = URL(string: path)?.appendingPathComponent(obj) {
                        print("deflating!")
                        let newURL:URL = URL(string: path)!.appendingPathComponent(newName)
                        try! FileManager.default.moveItem(atPath: url.path, toPath: newURL.path)
                        NotificationCenter.default.post(name: Notification.Name(rawValue: "InboxFile"), object: newURL)
                    }
                    return false
                }
                return obj != "Inbox" && self.isDirectory(path + "/" + obj)
            })

        self.table.reloadData()

        //cleanse cached values
        self.dataFolderSizes = store.dictionary(forKey: "data-folder-sizes") as! [String:String]
        let filteredMetadataKeys:[String] = self.dataFolderSizes.keys.filter({el in
            return self.dataFolders.contains(el)
        })

        var tmpMetaData:[String:String] = Dictionary()
        for file:String in filteredMetadataKeys {
            tmpMetaData[file] = self.dataFolderSizes[file]
        }
        self.dataFolderSizes = tmpMetaData
        self.store.set(tmpMetaData, forKey: "data-folder-sizes")

        self.dataFolderThumbs = store.dictionary(forKey: "data-folder-thumbs") as! [String:String]
        //print("\(self.dataFolderSizes)\n\(self.dataFolderThumbs)")
    }

    override func viewWillDisappear(_ animated: Bool) {
        self.store.set(self.dataFolderSizes, forKey: "data-folder-sizes")
        self.store.synchronize()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    //MARK: TableView Delegates
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.dataFolders.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell:MainViewTableCell = self.table.dequeueReusableCell(withIdentifier: "cell") as! MainViewTableCell

        let title:String = self.dataFolders[(indexPath as NSIndexPath).row]
        cell.title?.text = title

        if let size:String = self.dataFolderSizes[title] {
            cell.subtitle?.text = "Size: " + size
        }
        else if self.deflating && (indexPath as NSIndexPath).row == self.dataFolders.count - 1 {
            cell.subtitle?.text = "Decompressing dataset..."
        }
        else {
            //this can fail for very large files if synchronus.
            DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.background).async(execute: {
                let size:String = self.sizeForFolder(title)
                cell.subtitle?.text = "Size: " + size

                self.dataFolderSizes[title] = size
                self.store.set(self.dataFolderSizes, forKey: "data-folder-sizes")
            })
            cell.subtitle?.text = "Size: calculating..."
        }

        //see if there's an available thumbnail in the dataset
        if let image:UIImage = self.offlineThumbnail(title) {
//            print("offline thumb")
            cell.thumb?.image = image
        }
        // fetch the thumbnail from a url or the sd-web image cache?
        else if let imageSrc:String = self.dataFolderThumbs[title] {
//            print("cached thumb")
            cell.thumb?.sd_setImage(with: URL(string:imageSrc))
        }
        // set the thumbnail to the null-image
        else {
            cell.thumb?.image = UIImage(named: "null-image", in: Bundle.main, compatibleWith: nil)
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if self.deflating && (indexPath as NSIndexPath).row == self.dataFolders.count - 1 {
            print("not available")
            return
        }

        let webContentPath:URL = self.paths.webcontentData() as URL
        let dataPath:URL = self.paths.datasetsSubdirectory(dataFolders[(indexPath as NSIndexPath).row])

        do {
            try FileManager.default.removeItem(atPath: webContentPath.absoluteString)
        } catch {
            print("No symlink to remove")
        }

        do {
            try FileManager.default.createSymbolicLink(atPath: webContentPath.absoluteString, withDestinationPath: dataPath.absoluteString)
        } catch {
            print("problem creating symlink")
            print((error as NSError).debugDescription)
        }


        presentTonicView(self.dataFolders[(indexPath as NSIndexPath).row])
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        self.cellToDelete = (indexPath as NSIndexPath).row
        let alert:UIAlertView = UIAlertView(title: "Delete dataset?", message: "\(self.dataFolders[(indexPath as NSIndexPath).row]) will be deleted from the device.", delegate: self, cancelButtonTitle: "Delete", otherButtonTitles: "Cancel")
        alert.show()
    }

    // MARK: misc
    func offlineThumbnail(_ name:String) -> UIImage? {
        let path:URL = self.paths.datasetsSubdirectory(name)
        let list:[AnyObject]? = try! FileManager.default.contentsOfDirectory(atPath: path.absoluteString) as [AnyObject]?
        for file:String in list as! [String] {
            if (file.hasSuffix(".png") || file.hasSuffix(".jpg") || file.hasSuffix(".jpeg")) && !file.hasPrefix(".") {
                return UIImage(contentsOfFile: path.appendingPathComponent(file).absoluteString)
            }
        }
        return nil
    }

    func handleURL(_ notifURL:Notification) {
        if let url:URL = notifURL.object as? URL {
            let fName:String = url.lastPathComponent.components(separatedBy: ".").first!
            self.preparDeflate()
            DispatchQueue.main.async(execute: {
                self.dataFolders.append(fName)
                self.deflating = true
                self.table.reloadData()

                NVHTarGzip.sharedInstance().unTarGzipFile(atPath: url.path, toPath: self.paths.datasetsDirectory().path,
                completion: { (error:Error?) -> Void in
                    self.completeDeflate(error as! NSError)
                    self.deflating = false
                    self.table.reloadData()

                    try! FileManager.default.removeItem(atPath: url.path)
                })
            })
        }
    }
    
    func preparDeflate() {
        self.progress = Progress(totalUnitCount: 1)
        let keyPath:String = "fractionCompleted"
        self.progress.addObserver(self, forKeyPath: keyPath,
            options: NSKeyValueObservingOptions.initial,
            context: self.NVHProgressObserverContext)
        self.progress.becomeCurrent(withPendingUnitCount: 1)
    }
    
    func completeDeflate(_ error:NSError!) {
        let keyPath:String = "fractionCompleted"
        if error != nil {
            print("issue decompressing!")
        }
        self.progress.resignCurrent()
        self.progress.removeObserver(self, forKeyPath: keyPath, context: self.NVHProgressObserverContext)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if context == self.NVHProgressObserverContext {
            let _progress:Progress = object as! Progress;
            OperationQueue.main.addOperation({
                if fmod(_progress.fractionCompleted * 100, 10.0) == 0 {
                    print(_progress.fractionCompleted)
                }
            })
        }
    }

    func alertView(_ alertView: UIAlertView, clickedButtonAt buttonIndex: Int) {
        switch (buttonIndex) {
        case 1:
            self.tableView.setEditing(false, animated: true)
            break
        case 0:
            let path:URL = self.paths.datasetsSubdirectory(self.dataFolders[self.cellToDelete])
            DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async(execute: {
                try! FileManager.default.removeItem(atPath: path.absoluteString)
            })

            self.dataFolderSizes.removeValue(forKey: self.dataFolders[self.cellToDelete])
            UserDefaults.standard.set(self.dataFolderSizes, forKey: "data-folder-sizes")

            self.dataFolders.remove(at: self.cellToDelete)
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
        let newController:AboutViewController = storyboard?.instantiateViewController(withIdentifier: "AboutViewController") as! AboutViewController
        newController.title = "About"
        navigationController?.pushViewController(newController, animated: true)
    }

    func presentTonicView(_ viewTitle:String) {
        let newController = storyboard?.instantiateViewController(withIdentifier: "TonicViewController") as! TonicViewController
        newController.title = viewTitle
        navigationController?.pushViewController(newController, animated: true)
    }

    func sizeForFolder(_ folderName:String) -> String {
        let folderPath:String = self.paths.datasetsSubdirectory(folderName).absoluteString
        if !FileManager.default.fileExists(atPath: folderPath) {
            return "unknown"
        }
        let contents:[String] = try! FileManager.default.subpathsOfDirectory(atPath: folderPath) as [String]
        var folderSize:UInt64 = 0

        for file:String in contents {
            let fDict:NSDictionary = try! FileManager.default.attributesOfItem(atPath: folderPath + "/" + file) as NSDictionary
            folderSize += fDict.fileSize()
        }
        return ByteCountFormatter.string(fromByteCount: Int64(folderSize), countStyle: ByteCountFormatter.CountStyle.file)
    }

    func isDirectory(_ path:String) -> Bool {
        var isDir:ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        return isDir.boolValue
    }
}
