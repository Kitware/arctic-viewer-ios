//
//  DemoServer.swift
//  Swifter
//  Copyright (c) 2014 Damian Kołakowski. All rights reserved.
//

import Foundation

func demoServer(publicDir: String?) -> HttpServer {
    let server = HttpServer()
    
    if let publicDir = publicDir {
        server["/(.+)"] = HttpHandlers.directory(publicDir)
        server["/"] = {request in
            if let html = NSData(contentsOfFile:"\(publicDir)/index.html"){
                return .RAW(200, html)
            }
            else {
                return .NotFound
            }
        }
    }
    
    return server
}