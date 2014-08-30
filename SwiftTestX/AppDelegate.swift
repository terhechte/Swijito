//
//  AppDelegate.swift
//  Swijito
//
//  Created by Benedikt Terhechte on 09/06/14.
//  Copyright (c) 2014 Benedikt Terhechte. All rights reserved.
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
                            
    @IBOutlet var window: NSWindow?
    
    // TODO: Apparently Xcode 6 can't find the PhotoCollector object in interface builder and doesn't allow me to connect to it
    @IBOutlet var controller: PhotoCollector?


    func applicationDidFinishLaunching(aNotification: NSNotification?) {
        // Insert code here to initialize your application
        self.window?.titlebarAppearsTransparent = true
    }

    func applicationWillTerminate(aNotification: NSNotification?) {
        // Insert code here to tear down your application
    }

}

