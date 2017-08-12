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

    
    // The whole menu IBOutlet
    @IBOutlet weak var statusMenu: NSMenu!
    
    // Menu item IBOutlets
    @IBOutlet weak var disableForAppMenuItem: NSMenuItem!
    @IBOutlet weak var enableNightShiftMenuItem: NSMenuItem!
    @IBOutlet weak var adjustWarmthTitleMenuItem: NSMenuItem!
    @IBOutlet weak var statusTitleMenuItem: NSMenuItem!
    @IBOutlet weak var nightShiftStatus: NSMenuItem!
    @IBOutlet weak var launchNightShiftPrefsMenuItem: NSMenuItem!
    @IBOutlet weak var launchAboutDialogMenuItem: NSMenuItem!
    @IBOutlet weak var quitMenuItem: NSMenuItem!
    
    // References for the slider that controls Night Shift warmth
    @IBOutlet weak var nightShiftWarmthSlider: NSSlider!
    @IBOutlet weak var nigthShiftWarmthView: NSView! // Container view that contains the NSSlider
    
    let statusItem = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength) // Reference for the menu bar icon
    let blueLightClient = CBBlueLightClient() // Blue light client for controlling Night Shift
    
    
    var workspace : NSWorkspace = NSWorkspace.shared()
    var notificationCenter : NotificationCenter = NSWorkspace.shared().notificationCenter // Notification to receive notifications about app activation changes
    let nightShiftControlBundleIdentifier = NSRunningApplication.current().bundleIdentifier! // Identifier for this app
    let blackListedAppsPrefKey = NSRunningApplication.current().bundleIdentifier! +  ".BlackListedApps" // Key for storing Night Shift blacklisted apps
    let defaults = NSUserDefaultsController.shared().defaults // The defautlts to save balckisted apps array
    var currentApp : NSRunningApplication = NSWorkspace.shared().frontmostApplication! // NSRunningApplication instance for the current Applications
    var blackListedApps : [String] = [] // An array to contain bundle identifiers of black listed apps
    var intensityLevel : Float = 0 // This will store the current Night Shift strength
    
    var blueLightStatus : StatusData = StatusData.init() // This will store status data of CBBlueLightClient
    var applicationActiveObserver : AnyObject = NSObject.init() // Notification observer reference for NSWorkspaceDidActivateApplication
    var blueLightStrength : Float = 0  // Stores the strength of Night Shift
    var wasEnabled : Bool = false // Flag to store whether Night Shift was enabled in the last non blacklisted app
    var blueLightNotAvailableALert = NSAlert() // Dialog to show that Night Shift is not supported by the current hardware
    
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        if !CBBlueLightClient.supportsBlueLightReduction() {
            // Night Shift is not supported by the current hardware we show a dialog informing the user and exit the app
            blueLightNotAvailableALert.messageText = "ns_not_supported_for_device".localized
            blueLightNotAvailableALert.runModal()
            NSApplication.shared().terminate(self)
        }
        
        defaults.register(defaults: [blackListedAppsPrefKey : []]) // Initialize defaults
        blackListedApps = (defaults.object(forKey: blackListedAppsPrefKey) as? [String])! // Get blacklisted apps array from defaults
        blueLightClient.getStrength(&blueLightStrength) // Get the current strength and store it in blueLightStrenght
        blueLightClient.getBlueLightStatus(&blueLightStatus) // Get the current status of blue light and store it in blueLightStatus
        
        // We add a notification when an application becomes active
        applicationActiveObserver = self.notificationCenter.addObserver(forName: NSNotification.Name.NSWorkspaceDidActivateApplication, object: nil, queue: OperationQueue.main) {
            notification in
            self.currentApp = NSWorkspace.shared().frontmostApplication! // Update the currentapp NSRunningApplication reference
            self.updateBlueLightStatusForApp() // Handle app changes
            print("Front app is --> \(self.currentApp.localizedName!)")
        }
        
        
        let icon = NSImage(named: "statusicon")
        icon?.isTemplate = true // best for dark mode
        statusItem.image = icon // Set the icon for the meubar
        statusMenu.item(withTitle: "warmth")?.view = nigthShiftWarmthView // Replace the menu "warmth" with the NSSlider
        statusMenu.delegate = self // Make this class listen to menu opening events in the menuWillOpen(_)
        statusItem.menu = statusMenu // Set the menu for system the status bar item
        
        // Set starting titles for menus
        quitMenuItem.title = "quit".localized
        statusTitleMenuItem.title = "status_title".localized
        adjustWarmthTitleMenuItem.title = "adjust_warmth_title".localized
    }

    // Handles the Disable for App menu click
    @IBAction func disableForAppMenuItemClicked(_ sender: NSMenuItem) {
        if !blackListedApps.contains((currentApp.bundleIdentifier)!) {
            // If the app was not already in the black list add it
            blackListedApps.append((currentApp.bundleIdentifier)!)
            // Update the preferences with the new updated black list
            defaults.set(blackListedApps, forKey: blackListedAppsPrefKey)
            // Disable Night Shift
            blueLightClient.setEnabled(false)
        } else {
            // If the app was already on the black list remove it
            let index = blackListedApps.index(of: (currentApp.bundleIdentifier)!)
            blackListedApps.remove(at: index!)
            // Update the prefrences with the new updated black list
            defaults.set(blackListedApps, forKey: blackListedAppsPrefKey)
            if wasEnabled {
                // If Night shift was enabled for the last app 
                blueLightClient.setEnabled(true)
            }
        }
    }
    
    
    @IBAction func quitMenuItemClicked(_ sender: NSMenuItem) {
        NSApplication.shared().terminate(self)
    }
    
    @IBAction func turnOnNightShiftMenuItemClicked(_ sender: NSMenuItem) {
        if sender.state == 1 {
            sender.state = 0
            if blackListedApps.contains((currentApp.bundleIdentifier)!){
                wasEnabled = sender.state == 0
            } else {
                blueLightClient.setEnabled(false)
            }
        } else {
            sender.state = 1
            if blackListedApps.contains((currentApp.bundleIdentifier)!){
                wasEnabled = sender.state == 1
            } else {
                blueLightClient.setEnabled(true)
            }
        }
        
        nightShiftStatus.title = "ns_manually_turned_on_status".localized
    }
    

    
    func menuWillOpen(_ menu: NSMenu) {
        // Before the menu appears update all the nececessary information in the menu
        updateMenuStatus()
        var cct : Float = 0
        var str : Float = 0
        blueLightClient.getCCT(&cct)
        blueLightClient.getStrength(&str)
        print("Strength is \(str) and CCT is \(str)")
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        print("Removing observers")
        notificationCenter.removeObserver(applicationActiveObserver)
    }
    
    func updateBlueLightStatusForApp()  {
        if currentApp.bundleIdentifier == nightShiftControlBundleIdentifier {
            disableForAppMenuItem.isHidden = true
        } else {
            disableForAppMenuItem.isHidden = false
        }
        
        blueLightClient.getBlueLightStatus(&blueLightStatus)
        blueLightClient.getStrength(&blueLightStrength)
        
        
        if blackListedApps.contains((currentApp.bundleIdentifier)!) {
            wasEnabled = blueLightStatus.enabled == 1
            blueLightClient.setEnabled(false)
            disableForAppMenuItem.title =  String(format: "enable_ns_for_app".localized, self.currentApp.localizedName!)
        } else {
            if wasEnabled {
                blueLightClient.setEnabled(true)
            }
            
            disableForAppMenuItem.title = String(format: "disable_ns_for_app".localized, self.currentApp.localizedName!)
        }
    }

    func updateMenuStatus() {
        // Update menu titles and and strength slider
        // based on the status provided by CBBlueLightClient
        
        blueLightClient.getBlueLightStatus(&blueLightStatus) // Get the current blue light status
        
        print("Blue light status -> \(blueLightStatus)")
    
        blueLightClient.getStrength(&blueLightStrength)
        
        enableNightShiftMenuItem.state = Int(blueLightStatus.enabled)
        nightShiftWarmthSlider.integerValue = Int(blueLightStrength * 100)
        nightShiftWarmthSlider.isEnabled = blueLightStatus.enabled == 1

        
//        if blackListedApps.contains(currentApp.bundleIdentifier!) && blueLightStatus.enabled == 0 {
//            disableForAppMenuItem.isHidden = true
//        } else {
//            disableForAppMenuItem.isHidden = false
//        }
        
        if blueLightStatus.mode == 0 {
            nightShiftStatus.title = "ns_disabled_status".localized
        } else if blueLightStatus.mode == 1 {
            nightShiftStatus.title = "sunrset_to_sunrise_ns_status".localized
            enableNightShiftMenuItem.title = "turn_ns_on_until_sunrise".localized
        } else if blueLightStatus.sunSchedulePermitted == 0 && blueLightStatus.mode == 1{
            nightShiftStatus.title = "ns_needs_location_permission".localized
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
            
            nightShiftStatus.title = String(format:"custom_time_ns_status".localized, fromTime, toTime )
        
            enableNightShiftMenuItem.title = "turn_ns_on_until_to_tomorrow".localized
        }
    }
    
    
    @IBAction func launchDisplaysPrefPaneMenuItemClicked(_ sender: NSMenuItem) {
        NSWorkspace.shared().openFile("/System/Library/PreferencePanes/Displays.prefPane")
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

