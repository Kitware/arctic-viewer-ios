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

        let screenSize: CGRect = UIScreen.main.bounds
        let frameRect: CGRect = CGRect(x: 0, y: 0, width: screenSize.width, height: screenSize.height)

        // Create url request from local index.html file located in web_content
        let url: URL = URL(string: "http://localhost:\(self.port)/index.html")!
        let requestObj: URLRequest = URLRequest(url: url);

        self.wkWebView = WKWebView(frame: frameRect)
        let _ = self.wkWebView?.load(requestObj)
        self.wkWebView?.navigationDelegate = self
        self.view.insertSubview(self.wkWebView!, belowSubview: self.spinner)

        // set autolayout so the view is always 100% width and 100% height
        self.wkWebView.translatesAutoresizingMaskIntoConstraints = false
        let bindings:[String:AnyObject] = ["v1": self.wkWebView]
        self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-0-[v1]-0-|", options: NSLayoutFormatOptions.alignAllLeft, metrics: nil, views: bindings))
        self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-0-[v1]-0-|", options: NSLayoutFormatOptions.alignAllTop, metrics: nil, views: bindings))

        // always stay on,
        UIApplication.shared.isIdleTimerDisabled = true

        // disable 'swipe to go back' gesture
        self.navigationController?.interactivePopGestureRecognizer!.isEnabled = false

        //check for default fullscreen, if it's on for the first time or retoggled then an alert is shown.
        let store:UserDefaults = UserDefaults.standard
        self.fullscreen = store.bool(forKey: "fullscreen-viewer");
        if self.fullscreen && !store.bool(forKey: "fullscreen-default-alert") {
            let alert = UIAlertView(title: "Fullscreen By Default",
                message: "This view will initially appear fullscreen by default, shake to show the navigation bar." +
                "This setting can be toggled from the Settings app.",
                delegate: nil, cancelButtonTitle: "Ok")
            alert.show()
            store.set(true, forKey: "fullscreen-default-alert")
        }
        else if !store.bool(forKey: "fullscreen-default-alert") {
            store.set(false, forKey: "fullscreen-default-alert")
        }
        store.synchronize()

        // show a action button if the wifi is available.
        if let ip:String = getWifiIP() {
            self.ipText = "A server is running at:\n\(ip)" + (self.port == 80 ? "/" : ":\(self.port)/")
            let btnReload:UIBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.action, target: self, action: #selector(TonicViewController.showIpAlert))
            self.navigationController?.topViewController!.navigationItem.rightBarButtonItem = btnReload
            btnReload.isEnabled = true
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(self.fullscreen, animated: false)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        UIApplication.shared.isIdleTimerDisabled = false
        self.navigationController?.interactivePopGestureRecognizer!.isEnabled = true
    }

    func showIpAlert() {
        let alert:UIAlertView = UIAlertView(title: "Server IP", message: self.ipText, delegate: nil, cancelButtonTitle: "OK")
        alert.show()
    }

    // shake motion to go fullscreen
    override func motionEnded(_ motion: UIEventSubtype, with event: UIEvent?) {
        if motion == UIEventSubtype.motionShake {
            self.fullscreen = !self.fullscreen;
            self.navigationController?.setNavigationBarHidden(self.fullscreen, animated: true)
            self.setNeedsStatusBarAppearanceUpdate()

            let store:UserDefaults = UserDefaults.standard
            let times:Int = store.integer(forKey: "fullscreen-alert-times")
            if self.fullscreen && !store.bool(forKey: "fullscreen-viewer") && times < 3 {
                let alert = UIAlertView(title: "Fullscreen activated",
                    message: "A shaking motion toggles fullscreen, shake to undo. Fullscreen can be set to default from the Settings app.",
                    delegate: nil, cancelButtonTitle: "OK")
                alert.show()

                store.set(times + 1, forKey: "fullscreen-alert-times")
                store.synchronize()
            }
        }
    }

    override var prefersStatusBarHidden : Bool {
        return fullscreen
    }

    // there is a spinner that shows before the WebView is ready.
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.spinner.stopAnimating()
    }

    func startServer() {
        let serverPath:String = self.paths.webcontentDirectory().absoluteString
        let server = self.makeServer(serverPath)
        self.server = server
        do {
            try self.server.start(self.port, forceIPv4: true)
        } catch {
            print("Server start error on port \(self.port):: \(error.localizedDescription)")
        }
    }

    func makeServer(_ publicDir: String?) -> HttpServer {
        let server = HttpServer()

        if let publicDir = publicDir {
            server.GET["/:file"] = { request in
                if FileManager.default.fileExists(atPath: "\(publicDir)\(request.path).gz") {
                    let response = NSData(contentsOfFile: "\(publicDir)\(request.path).gz")
                    //print("response with gzip file: \(request.path)")
                    return HttpResponse.raw(200, "OK", ["Content-Encoding": "gzip"], { try $0.write(response!) })
                }

                if FileManager.default.fileExists(atPath: "\(publicDir)\(request.path)") {
                    let response = NSData(contentsOfFile: "\(publicDir)\(request.path)")
                    //print("response with file: \(request.path)")
                    return HttpResponse.raw(200, "OK", nil, { try $0.write(response!) })
                } else {
                    return HttpResponse.notFound
                }
            }
            server.GET["/"] = {request in
                if let html = NSData(contentsOfFile:"\(publicDir)/index.html"){
                    return HttpResponse.raw(200, "OK", nil, { try $0.write(html) })
                }
                else {
                    return HttpResponse.notFound
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

