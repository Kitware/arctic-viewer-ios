//
//  ViewController.swift
//  ArcticViewer
//
//  Created by Tristan on 7/13/15.
//  Copyright (c) 2015 Kitware. All rights reserved.
//

import UIKit
import WebKit
import Swifter

class TonicViewController: UIViewController, WKNavigationDelegate {

    @IBOutlet weak var spinner: UIActivityIndicatorView!

    var wkWebView: WKWebView!
    var server: HttpServer!
    var fullscreen:Bool = false
    var ipText:String = ""

    #if arch(i386) || arch(x86_64)
        let port:in_port_t = 40444
    #else
        let port:in_port_t = 80
    #endif
    
    let paths:Paths = Paths()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.startServer()

        let screenSize: CGRect = UIScreen.mainScreen().bounds
        let frameRect: CGRect = CGRect(x: 0, y: 0, width: screenSize.width, height: screenSize.height)

        // Create url request from local index.html file located in web_content
        let url: NSURL = NSURL(string: "http://localhost:\(self.port)/index.html")!
        let requestObj: NSURLRequest = NSURLRequest(URL: url);

        self.wkWebView = WKWebView(frame: frameRect)
        self.wkWebView?.loadRequest(requestObj)
        self.wkWebView?.navigationDelegate = self
        self.view.insertSubview(self.wkWebView!, belowSubview: self.spinner)

        // set autolayout so the view is always 100% width and 100% height
        //self.wkWebView.setTranslatesAutoresizingMaskIntoConstraints(false)
        let bindings:[String:AnyObject] = ["v1": self.wkWebView]
        self.view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|-0-[v1]-0-|", options: NSLayoutFormatOptions.AlignAllLeft, metrics: nil, views: bindings))
        self.view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|-0-[v1]-0-|", options: NSLayoutFormatOptions.AlignAllTop, metrics: nil, views: bindings))

        // always stay on,
        UIApplication.sharedApplication().idleTimerDisabled = true

        // disable 'swipe to go back' gesture
        self.navigationController?.interactivePopGestureRecognizer!.enabled = false

        //check for default fullscreen, if it's on for the first time or retoggled then an alert is shown.
        let store:NSUserDefaults = NSUserDefaults.standardUserDefaults()
        self.fullscreen = store.boolForKey("fullscreen-viewer");
        if self.fullscreen && !store.boolForKey("fullscreen-default-alert") {
            let alert = UIAlertView(title: "Fullscreen By Default",
                message: "This view will initially appear fullscreen by default, shake to show the navigation bar." +
                "This setting can be toggled from the Settings app.",
                delegate: nil, cancelButtonTitle: "Ok")
            alert.show()
            store.setBool(true, forKey: "fullscreen-default-alert")
        }
        else if !store.boolForKey("fullscreen-default-alert") {
            store.setBool(false, forKey: "fullscreen-default-alert")
        }
        store.synchronize()

        // show a action button if the wifi is available.
        if let ip:String = self.getWifiIP() {
            self.ipText = "A server is running at:\n\(ip)" + (self.port == 80 ? "/" : ":\(self.port)/")
            let btnReload:UIBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Action, target: self, action: Selector("showIpAlert"))
            self.navigationController?.topViewController!.navigationItem.rightBarButtonItem = btnReload
            btnReload.enabled = true
        }
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(self.fullscreen, animated: false)
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        UIApplication.sharedApplication().idleTimerDisabled = false
        self.navigationController?.interactivePopGestureRecognizer!.enabled = true
    }

    func getWifiIP() -> String? {
        var address:String?

        // Get list of all interfaces on the local machine:
        var ifaddr:UnsafeMutablePointer<ifaddrs> = nil
        if getifaddrs(&ifaddr) == 0 {

            // For each interface ...
            for (var ptr = ifaddr; ptr != nil; ptr = ptr.memory.ifa_next) {
                let interface = ptr.memory

                // Check only IPv4 interfaces //or IPv6 interface:
                let addrFamily = interface.ifa_addr.memory.sa_family
                if addrFamily == UInt8(AF_INET) { //|| addrFamily == UInt8(AF_INET6) {

                    // Check interface name:
                    if let name = String.fromCString(interface.ifa_name) where name == "en0" {

                        // Convert interface address to a human readable string:
                        var addr = interface.ifa_addr.memory
                        var hostname = [CChar](count: Int(NI_MAXHOST), repeatedValue: 0)
                        getnameinfo(&addr, socklen_t(interface.ifa_addr.memory.sa_len),
                            &hostname, socklen_t(hostname.count),
                            nil, socklen_t(0), NI_NUMERICHOST)
                        address = String.fromCString(hostname)
                    }
                }
            }
            freeifaddrs(ifaddr)
        }

        return address
    }

    func showIpAlert() {
        let alert:UIAlertView = UIAlertView(title: "Server IP", message: self.ipText, delegate: nil, cancelButtonTitle: "OK")
        alert.show()
    }

    // shake motion to go fullscreen
    override func motionEnded(motion: UIEventSubtype, withEvent event: UIEvent?) {
        if motion == UIEventSubtype.MotionShake {
            self.fullscreen = !self.fullscreen;
            self.navigationController?.setNavigationBarHidden(self.fullscreen, animated: true)
            self.setNeedsStatusBarAppearanceUpdate()

            let store:NSUserDefaults = NSUserDefaults.standardUserDefaults()
            let times:Int = store.integerForKey("fullscreen-alert-times")
            if self.fullscreen && !store.boolForKey("fullscreen-viewer") && times < 3 {
                let alert = UIAlertView(title: "Fullscreen activated",
                    message: "A shaking motion toggles fullscreen, shake to undo. Fullscreen can be set to default from the Settings app.",
                    delegate: nil, cancelButtonTitle: "OK")
                alert.show()

                store.setInteger(times + 1, forKey: "fullscreen-alert-times")
                store.synchronize()
            }
        }
    }

    override func prefersStatusBarHidden() -> Bool {
        return fullscreen
    }

    // there is a spinner that shows before the WebView is ready.
    func webView(webView: WKWebView, didFinishNavigation navigation: WKNavigation!) {
        self.spinner.stopAnimating()
    }

    func startServer() {
        let serverPath:String = self.paths.webcontentDirectory().absoluteString
        let server = self.makeServer(serverPath)
        self.server = server
        var error: NSError?
        if !server.start(self.port, error: &error) {
            print("Server start error on port \(self.port):: \(error?.localizedDescription)")
        }
    }

    func makeServer(publicDir: String?) -> HttpServer {
        let server = HttpServer()

        if let publicDir = publicDir {
            server["/(.+)"] = HttpHandlers.directory(publicDir)
            server["/"] = {request in
                if let html = NSData(contentsOfFile:"\(publicDir)/index.html"){
                    return HttpResponse.RAW(200, "OK", nil, html)
                }
                else {
                    return HttpResponse.NotFound
                }
            }
        }
        
        return server
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    deinit {
        server.stop();
    }
}

