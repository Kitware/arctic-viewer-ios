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
    func some(_ fn: (Element) -> Bool) -> Bool {
        var out = false
        for i in self {
            out = out || fn(i);
        }
        return out
    }
}

enum UIUserInterfaceIdiom : Int {
    case unspecified

    case phone // iPhone and iPod touch style UI
    case pad   // iPad style UI
}

// Partial code from SwiftyTimer,       //
// https://github.com/radex/SwiftyTimer //
private class NSTimerActor {
    var block: () -> ()

    init(_ block: @escaping () -> ()) {
        self.block = block
    }

    @objc func fire() {
        block()
    }
}

extension Timer {
    class func new(after interval: TimeInterval, _ block: @escaping () -> ()) -> Timer {
        let actor = NSTimerActor(block)
        return self.init(timeInterval: interval, target: actor, selector: #selector(NSTimerActor.fire), userInfo: nil, repeats: false)
    }

    public class func after(_ interval: TimeInterval, _ block: @escaping () -> Void) -> Timer {
        let timer = Timer.new(after: interval, block)
        timer.start()
        return timer
    }

    public func start(runLoop: RunLoop = .current, modes: RunLoopMode...) {
        let modes = modes.isEmpty ? [.defaultRunLoopMode] : modes

        for mode in modes {
            runLoop.add(self, forMode: mode)
        }
    }
}

// end SwiftyTimer //

func getWifiIP() -> String? {
    var address:String?

    // Get list of all interfaces on the local machine:
    var ifaddr : UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0 else { return nil }
    guard let firstAddr = ifaddr else { return nil }

    // For each interface ...
    for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
        let flags = Int32(ptr.pointee.ifa_flags)
        var addr = ptr.pointee.ifa_addr.pointee

        // Check for running IPv4, IPv6 interfaces. Skip the loopback interface.
        if (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING) {
            if addr.sa_family == UInt8(AF_INET) || addr.sa_family == UInt8(AF_INET6) {

                // Convert interface address to a human readable string:
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if (getnameinfo(&addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST) == 0) {
                    address = String(cString: hostname)
                }
            }
        }
    }
    freeifaddrs(ifaddr)
    return address
}

func isWifiOn() -> Bool {
    var Status:Bool = false
    let url = URL(string: "http://kitware.com/")
    let request = NSMutableURLRequest(url: url!)
    request.httpMethod = "HEAD"
    request.cachePolicy = NSURLRequest.CachePolicy.reloadIgnoringLocalAndRemoteCacheData
    request.timeoutInterval = 10.0

    var response: URLResponse?

    _ = try! NSURLConnection.sendSynchronousRequest(request as URLRequest, returning: &response) as Data?

    if let httpResponse = response as? HTTPURLResponse {
        if httpResponse.statusCode == 200 {
            Status = true
        }
    }

    return Status
}
