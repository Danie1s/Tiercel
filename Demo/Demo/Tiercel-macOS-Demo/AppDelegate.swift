//
//  AppDelegate.swift
//  Tiercel-macOS-Demo
//
//  Created by Daniels on 2020/8/17.
//  Copyright © 2020 Daniels. All rights reserved.
//

import Cocoa
import Tiercel

let appDelegate = NSApplication.shared.delegate as! AppDelegate

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    let sessionManager1 = SessionManager("ViewController1", configuration: SessionConfiguration())
    
    var sessionManager2: SessionManager = {
        var configuration = SessionConfiguration()
        configuration.allowsCellularAccess = true
        let path = Cache.defaultDiskCachePathClosure("Test")
        let cacahe = Cache("ViewController2", downloadPath: path)
        let manager = SessionManager("ViewController2", configuration: configuration, cache: cacahe, operationQueue: DispatchQueue(label: "com.Tiercel.SessionManager.operationQueue"))
        return manager
    }()
    
    let sessionManager3 = SessionManager("ViewController3", configuration: SessionConfiguration())
    

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

