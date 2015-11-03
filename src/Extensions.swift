//
//  Extensions.swift
//  ArcticViewer
//
//  Created by Tristan on 7/14/15.
//  Copyright (c) 2015 Kitware. All rights reserved.
//

import Foundation

extension Array {
    // equivalent to Javascript's Array.prototype.some
    // from: https://github.com/tristaaan/jsSwift/blob/master/jsSwift/jsArray.swift
    func some(fn: (Element) -> Bool) -> Bool {
        var out = false
        for i in self {
            out = out || fn(i);
        }
        return out
    }
}

enum UIUserInterfaceIdiom : Int {
    case Unspecified

    case Phone // iPhone and iPod touch style UI
    case Pad   // iPad style UI
}

// Partial code from SwiftyTimer,       //
// https://github.com/radex/SwiftyTimer //
private class NSTimerActor {
    var block: () -> ()

    init(_ block: () -> ()) {
        self.block = block
    }

    @objc func fire() {
        block()
    }
}

extension NSTimer {
    class func new(after interval: NSTimeInterval, _ block: () -> ()) -> NSTimer {
        let actor = NSTimerActor(block)
        return self.init(timeInterval: interval, target: actor, selector: "fire", userInfo: nil, repeats: false)
    }

    public class func after(interval: NSTimeInterval, _ block: () -> Void) -> NSTimer {
        let timer = NSTimer.new(after: interval, block)
        timer.start()
        return timer
    }

    public func start(runLoop: NSRunLoop = NSRunLoop.currentRunLoop(), modes: String...) {
        let modes = modes.count != 0 ? modes : [NSDefaultRunLoopMode]

        for mode in modes {
            runLoop.addTimer(self, forMode: mode)
        }
    }
}

func isWifiOn() -> Bool {
    var Status:Bool = false
    let url = NSURL(string: "http://kitware.com/")
    let request = NSMutableURLRequest(URL: url!)
    request.HTTPMethod = "HEAD"
    request.cachePolicy = NSURLRequestCachePolicy.ReloadIgnoringLocalAndRemoteCacheData
    request.timeoutInterval = 10.0

    var response: NSURLResponse?

    _ = try! NSURLConnection.sendSynchronousRequest(request, returningResponse: &response) as NSData?

    if let httpResponse = response as? NSHTTPURLResponse {
        if httpResponse.statusCode == 200 {
            Status = true
        }
    }

    return Status
}

// end SwiftyTimer //