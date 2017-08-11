//
//  AppDelegate.swift
//  Night Shift Control
//
//  Created by Isaias M. Teweldeberhan on 8/8/17.
//  Copyright © 2017 Isaias M. Teweldeberhan. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var enableNightShiftMenuItem: NSMenuItem!
    @IBOutlet weak var disableForAppMenuItem: NSMenuItem!
    @IBOutlet weak var nightShiftStatus: NSMenuItem!
    @IBOutlet weak var nightShiftWarmthSlider: NSSlider!
    @IBOutlet weak var nigthShiftWarmthView: NSView!
    
    
    let statusItem = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength)
    let blueLightClient = CBBlueLightClient()
    
    var workspace : NSWorkspace = NSWorkspace.shared()
    var notificationCenter : NotificationCenter = NSWorkspace.shared().notificationCenter
    let nightShiftControlBundleIdentifier = NSRunningApplication.current().bundleIdentifier!
    let blackListedAppsPrefKey = NSRunningApplication.current().bundleIdentifier! +  ".BlackListedApps"
    let intensityLevelPrefKey = NSRunningApplication.current().bundleIdentifier! +  ".IntentsityLevel"
    let defaults = NSUserDefaultsController.shared().defaults
    var currentApp : NSRunningApplication = NSWorkspace.shared().frontmostApplication!
    var blackListedApps : [String] = []
    var intensityLevel : Float = 0
    
    var blueLightStatus : StatusData = StatusData.init()
    var applicationActiveObserver : AnyObject = NSObject.init()
    var pastStrength : Float = 0
    var wasEnabled : Bool = false
    
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        defaults.register(defaults: [blackListedAppsPrefKey : [], intensityLevelPrefKey: 80])
        blackListedApps = (defaults.object(forKey: blackListedAppsPrefKey) as? [String])!
        blueLightClient.getStrength(&pastStrength)
        
        applicationActiveObserver = self.notificationCenter.addObserver(forName: NSNotification.Name.NSWorkspaceDidActivateApplication, object: nil, queue: OperationQueue.main) {
            notification in
            self.currentApp = NSWorkspace.shared().frontmostApplication!
            self.setBlueLightForApp()
            print("Front app is --> \(self.currentApp.localizedName!)")
        }
        
    
        
        let icon = NSImage(named: "statusicon")
        icon?.isTemplate = true // best for dark mode
        statusItem.image = icon
        
        statusMenu.item(withTitle: "warmth")?.view = nigthShiftWarmthView
        
        
        
        if let button = statusItem.button {
            print("Adding icon and action to menubar button")
            button.image = icon
        }
        
        statusMenu.delegate = self
        statusItem.menu = statusMenu
    }
    

    @IBAction func disableForAppMenuItemClicked(_ sender: NSMenuItem) {
        if !blackListedApps.contains((currentApp.bundleIdentifier)!) {
            blackListedApps.append((currentApp.bundleIdentifier)!)
            defaults.set(blackListedApps, forKey: blackListedAppsPrefKey)
            blueLightClient.setEnabled(false)
        } else {
            let index = blackListedApps.index(of: (currentApp.bundleIdentifier)!)
            blackListedApps.remove(at: index!)
            defaults.set(blackListedApps, forKey: blackListedAppsPrefKey)
            blueLightClient.setEnabled(true)
        }
    }
    
    
    
    
    @IBAction func quitMenuItemClicked(_ sender: NSMenuItem) {
        NSApplication.shared().terminate(self)
    }
    
    @IBAction func enableNightShiftMenuItemClicked(_ sender: NSMenuItem) {
        if sender.state == 1 {
            sender.state = 0
            blueLightClient.setEnabled(false)
        } else {
            sender.state = 1
            blueLightClient.setEnabled(true)
        }
        
            //nightShiftStatus.title = "Enabled Manually"
    }
    
    @IBAction func openNightShiftPreferencesMenuItemClicked(_ sender: NSMenuItem) {
    }
    
    
    
//
//    @IBAction func nightShiftIntensityChosen(_ sender: NSMenuItem) {
//        intensityLevel = Float.init(sender.tag)/100
//        blueLightClient.setStrength(intensityLevel , commit: true)
//    }
//    
    func destroyObservers() {
        print("Removing observers")
        notificationCenter.removeObserver(applicationActiveObserver)
    }

    
    func menuWillOpen(_ menu: NSMenu) {
        // Before the menu appears update all the nececessary information in the menu
        updateMenus()
        print("Strength is strength \(pastStrength)")
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        destroyObservers()
    }
    
    func setBlueLightForApp()  {
        if currentApp.bundleIdentifier == nightShiftControlBundleIdentifier {
            disableForAppMenuItem.isHidden = true
        } else {
            disableForAppMenuItem.isHidden = false
        }
        
        blueLightClient.getBlueLightStatus(&blueLightStatus)
        blueLightClient.getStrength(&pastStrength)
        
        
        if blackListedApps.contains((currentApp.bundleIdentifier)!) {
            wasEnabled = blueLightStatus.enabled == 1
            blueLightClient.setEnabled(false)
            disableForAppMenuItem.title = "Enable for “\(self.currentApp.localizedName!)“"
        } else {
            if pastStrength > 0 && wasEnabled {
                blueLightClient.setStrength(pastStrength, commit: true)
                blueLightClient.setEnabled(true)
            }
            
            disableForAppMenuItem.title = "Disable for “\(self.currentApp.localizedName!)“"
        }
    }

    func updateMenus() {
        // Update menus
        blueLightClient.getBlueLightStatus(&blueLightStatus)
        
        print("Blue light status -> \(blueLightStatus)")
        
        
        blueLightClient.getStrength(&pastStrength)
        
        enableNightShiftMenuItem.state = Int(blueLightStatus.enabled)
        nightShiftWarmthSlider.integerValue = Int(pastStrength) * 100

        
//        if blackListedApps.contains(currentApp.bundleIdentifier!) && blueLightStatus.enabled == 0 {
//            disableForAppMenuItem.isHidden = true
//        } else {
//            disableForAppMenuItem.isHidden = false
//        }
        
        if blueLightStatus.mode == 0 {
            nightShiftStatus.title = "Night Shift is Disabled"
        } else if blueLightStatus.mode == 1 {
            nightShiftStatus.title = "Enabled from Sunset to Sunrise"
            enableNightShiftMenuItem.title = "Turn On Until Sunrise "
        } else if blueLightStatus.sunSchedulePermitted == 0 && blueLightStatus.mode == 1{
            nightShiftStatus.title = "Needs Location Permission"
        } else if blueLightStatus.mode == 2 {
            
            var fromHour : Int32 = blueLightStatus.schedule.fromTime.hour
            let fromMinute : Int32 = blueLightStatus.schedule.fromTime.minute
            
            var fromAMPM : String
            
            var toHour : Int32 = blueLightStatus.schedule.toTime.hour
            let toMinute : Int32 = blueLightStatus.schedule.toTime.minute
            
            var toAMPM : String
            var fromTime : String
            var toTime : String
            
            if fromHour == 0 {
                fromHour = 12
                fromAMPM = "AM"
            } else if fromHour < 12 {
                fromAMPM = "AM"
            } else {
                fromAMPM = "PM"
                if fromHour > 12 {
                    fromHour = blueLightStatus.schedule.fromTime.hour - 12
                }
            }
            
            if toHour == 0 {
                toHour = 12
                toAMPM = "AM"
            } else if toHour < 12 {
                toAMPM = "AM"
            } else {
                toAMPM = "PM"
                if toHour > 12 {
                    toHour = blueLightStatus.schedule.toTime.hour - 12
                }
            }
            
            if fromMinute == 0 {
                fromTime = "\(fromHour):00 " + fromAMPM
            } else {
                fromTime = "\(fromHour):\(fromMinute) " + fromAMPM
            }
            
            if toMinute == 0 {
                toTime = "\(toHour):00 " + toAMPM
            } else {
                toTime = "\(toHour):\(toMinute) " + toAMPM
            }
            
            nightShiftStatus.title = "Enabled from \(fromTime) to \(toTime)"
            enableNightShiftMenuItem.title = "Turn On Until Tomorrow"
        }

        
        
        
    }

    @IBAction func onNightShiftWarmSliderChanged(_ sender: NSSlider) {
        if sender.integerValue == 0 {
            blueLightClient.setEnabled(false)
            enableNightShiftMenuItem.state = 0
        } else {
            enableNightShiftMenuItem.state = 1
            blueLightClient.setEnabled(true)
            blueLightClient.setStrength(sender.floatValue/100, commit: true)
        }
        
        
        print("Slider is at \(sender.integerValue)")
    }
}

