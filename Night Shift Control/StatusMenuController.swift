//
//  StatusMenuController.swift
//  Night Shift Control
//
//  Created by Isaias M. Teweldeberhan on 8/8/17.
//  Copyright © 2017 Isaias M. Teweldeberhan. All rights reserved.
//

import Cocoa

class StatusMenuController: NSObject, NSApplicationDelegate {
    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var enableNightShiftMenuItem: NSMenuItem!
    @IBOutlet weak var disableNightShiftMenuItem: NSMenuItem!
    
    @IBOutlet weak var nightShiftIntensityMenuItem: NSMenuItem!
    let statusItem = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength)
    let blueLightClient = CBBlueLightClient()
    
    var workspace : NSWorkspace = NSWorkspace.shared()
    var notificationCenter : NotificationCenter = NSWorkspace.shared().notificationCenter
    

    let activeApplicationObserver = NSWorkspace.shared().notificationCenter.addObserver(forName: NSNotification.Name.NSWorkspaceDidActivateApplication, object: nil, queue: OperationQueue.main) {
        notification in
        print("\(NSWorkspace.shared().frontmostApplication?.bundleIdentifier) is on front")
    }

    
    
    
    override func awakeFromNib() {
        
        
        let icon = NSImage(named: "statusicon")
        icon?.isTemplate = true // best for dark mode
        statusItem.image = icon
        statusItem.menu = statusMenu
    }
    
    
    
    
    @IBAction func quitMenuItemClicked(_ sender: NSMenuItem) {
        NSApplication.shared().terminate(self)
    }
    
    @IBAction func enableNightShiftMenuItemClicked(_ sender: NSMenuItem) {
        blueLightClient.setEnabled(true)
        nightShiftIntensityMenuItem.isEnabled = true
    }
    
    
    @IBAction func disableNightShiftMenuItemClicked(_ sender: NSMenuItem) {
        blueLightClient.setEnabled(false)
    }
    
    @IBAction func nightShiftIntensityChosen(_ sender: NSMenuItem) {
        blueLightClient.setStrength(Float.init(sender.tag)/100 , commit: true)
    }
    
    func destroyObservers() {
        print("Removing observers")
        notificationCenter.removeObserver(activeApplicationObserver)
    }

    func applicationWillTerminate(_ notification: Notification) {
        destroyObservers()
    }
    
}
