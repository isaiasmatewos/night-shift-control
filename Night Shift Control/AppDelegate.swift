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
    var disabledForApp : Bool = false
    
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        if !CBBlueLightClient.supportsBlueLightReduction() {
            // Night Shift is not supported by the current hardware we show a dialog informing the user and exit the app
            blueLightNotAvailableALert.messageText = "ns_not_available_dialog_title".localized
            blueLightNotAvailableALert.informativeText = "ns_not_available_dialog_info".localized
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
        launchNightShiftPrefsMenuItem.title = "open_display_pref_pane".localized
        launchAboutDialogMenuItem.title = "about".localized
    }
    
    // Handles the Disable for App menu click
    @IBAction func disableForAppMenuItemClicked(_ sender: NSMenuItem) {
        if !blackListedApps.contains((currentApp.bundleIdentifier)!) {
            // If the app was not already in the black list add it
            blackListedApps.append((currentApp.bundleIdentifier)!)
            // Update the preferences with the new updated black list
            defaults.set(blackListedApps, forKey: blackListedAppsPrefKey)
            // Disable Night Shift
            disabledNightShift(forApp: true)
        } else {
            // If the app was already on the black list remove it
            let index = blackListedApps.index(of: (currentApp.bundleIdentifier)!)
            blackListedApps.remove(at: index!)
            // Update the prefrences with the new updated black list
            defaults.set(blackListedApps, forKey: blackListedAppsPrefKey)
            if wasEnabled {
                // If Night shift was enabled for the last app 
                enableNightShift()
            }
        }
    }
    
    
    @IBAction func turnOnNightShiftMenuItemClicked(_ sender: NSMenuItem) {
        // Called when a manual turn on menu item is clicked
        if sender.state == 1 {
            // Night Shift was previously enabled
            sender.state = 0 // We toggle it to disabled
            if !blackListedApps.contains((currentApp.bundleIdentifier)!){
                // If the front app was not balck listed disable Night Shift
                disabledNightShift(forApp: false)
            }
            
        } else {
            // Night Shift was previously disabled
            sender.state = 1 // We toggle it to enabled
            if blackListedApps.contains((currentApp.bundleIdentifier)!){
                // If the front app was black listed, disable Night Shift for the app
                disabledNightShift(forApp: true)
            } else {
                // Otherwise enable night shift
                enableNightShift()
            }
        }
        
        
    }
    
    
    @IBAction func onNightShiftWarmSliderChanged(_ sender: NSSlider) {
        // Called when the warmth slider changed value
        if sender.integerValue == 0 {
            // If the slider value is zero we turn off NightShift alltogether
            disabledNightShift(forApp: false)
            enableNightShiftMenuItem.state = 0
        } else {
            enableNightShiftMenuItem.state = 1
            blueLightClient.setStrength(sender.floatValue/100, commit: true)
        }
    }
    
    @IBAction func launchDisplaysPrefPaneMenuItemClicked(_ sender: NSMenuItem) {
        // Launches display prefernces pane
        NSWorkspace.shared().openFile("/System/Library/PreferencePanes/Displays.prefPane")
    }
    
    @IBAction func launcAboutDialogMenuItemClicked(_ sender: NSMenuItem) {
        // Launches about dialog
        NSApplication.shared().orderFrontStandardAboutPanel(self)
    }
    
    
    @IBAction func quitMenuItemClicked(_ sender: NSMenuItem) {
        // Quits app
        NSApplication.shared().terminate(self)
    }
    
    func menuWillOpen(_ menu: NSMenu) {
        // Invoked when status menu is about about to be opened,
        updateMenuStatus()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        print("Removing observers")
        notificationCenter.removeObserver(applicationActiveObserver)
    }
    
    func updateBlueLightStatusForApp()  {
        // Decides whether Night Shift should be disabled or enabled for the current app
        if currentApp.bundleIdentifier == nightShiftControlBundleIdentifier {
            // If "Night Shift Control" is the front app remove the disable for app menu
            disableForAppMenuItem.isHidden = true
        } else {
            disableForAppMenuItem.isHidden = false
        }
        
        // Get the latest blueLightStatus and blueLight Strength
        blueLightClient.getBlueLightStatus(&blueLightStatus)
        
        
        if blackListedApps.contains((currentApp.bundleIdentifier)!) {
            // Black listed app
            if !disabledForApp {
                // If it hasn't already been disabled, disable Night Shift
                disabledNightShift(forApp: true)
            }
            // Changes the title to "Enable for {Black Listed App}"
            disableForAppMenuItem.title =  String(format: "enable_ns_for_app".localized, self.currentApp.localizedName!)
        } else {
            // Non black listed app
            if disabledForApp {
                // Enable it if it has been disabled for a specific app
                enableNightShift()
            }
            // Changes the title to "Disable for {Black Listed App}"
            disableForAppMenuItem.title = String(format: "disable_ns_for_app".localized, self.currentApp.localizedName!)
        }
    }

    func enableNightShift() {
        blueLightClient.setEnabled(true)
        disabledForApp = false
    }
    
    func disabledNightShift(forApp: Bool) {
        blueLightClient.getBlueLightStatus(&blueLightStatus)
        disabledForApp = forApp &&  blueLightStatus.enabled == 1
        blueLightClient.setEnabled(false)
        
    }
    
    
    func updateMenuStatus() {
        // Updates menu titles and and strength slider based on the status provided by CBBlueLightClient
        print("Blue light status -> \(blueLightStatus)")

        
        blueLightClient.getBlueLightStatus(&blueLightStatus) // Get the current blue light status
        blueLightClient.getStrength(&blueLightStrength) // Get the current blue light strength
        
        enableNightShiftMenuItem.state = Int(blueLightStatus.enabled) // Update the Night Shift toggle menu based on blueLightStatus
        nightShiftWarmthSlider.integerValue = Int(blueLightStrength * 100) // Update warmth slider based on blueLightStrength
        nightShiftWarmthSlider.isEnabled = blueLightStatus.enabled == 1 // Enable/Disable slider based on blueLightStatus
        
        
        // Updates status based on blueLightStatus
        if blueLightStatus.mode == 0 {
            // Night shift is turned off
            if blueLightStatus.enabled == 1 {
                // If Night Shift was disabled turn the status title to "Turned On Manually"
                nightShiftStatus.title = "ns_manually_turned_on_status".localized
            } else {
                nightShiftStatus.title = "ns_disabled_status".localized
            }
        } else if blueLightStatus.mode == 1 && blueLightStatus.sunSchedulePermitted == 1 {
            // Night shift is enabled from sunset to sunrise
            nightShiftStatus.title = "sunrset_to_sunrise_ns_status".localized
            enableNightShiftMenuItem.title = "turn_ns_on_until_sunrise".localized
        } else if blueLightStatus.sunSchedulePermitted == 0 && blueLightStatus.mode == 1{
            // Night shift requires location permission to be from sunset to sunrise
            nightShiftStatus.title = "ns_needs_location_permission".localized
        } else if blueLightStatus.mode == 2 {
            // Night shift is enabled in a specific time range
            // Changing the time range to AM/PM and adding leading zeros
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
            } else if fromMinute < 10{
                fromTime = "\(fromHour):0\(fromMinute) " + fromAMPM
            } else {
                fromTime = "\(fromHour):\(fromMinute) " + fromAMPM
            }
            
            if toMinute == 0 {
                toTime = "\(toHour):00 " + toAMPM
            } else if toMinute < 10{
                toTime = "\(toHour):0\(toMinute) " + toAMPM
            } else  {
                toTime = "\(toHour):\(toMinute) " + toAMPM
            }
            
            // Changed the title to "Enabled {fromTime} to {toTime}"
            nightShiftStatus.title = String(format:"custom_time_ns_status".localized, fromTime, toTime )
            enableNightShiftMenuItem.title = "turn_ns_on_until_to_tomorrow".localized
        }
    }
    
}

