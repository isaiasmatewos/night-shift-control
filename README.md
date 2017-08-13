# Night Shift Control

## Introduction

Night Shift Control is a simple menubar app for controlling Night Shift.
It let's you disable Night Shift for certain apps. Watch the belwow GIF for demo 

## Screenshots



## Features

* Disable Night Shift for apps for your choice
* Easily turn on Night Shift from the menubar
* Control Night Shift warmth from the menubar
* Shows the current Night Shift status 

## Download

Download from the releases tab [here](https://www.imore.com/how-open-apps-unidentified-developers-mac)

## How to install

This app is not officially singed so you will need to disable Gatekeeper temporarily to install it.
You can disable Gatekeeper using the following command:

`sudo spctl --master-disable`

Then unzip the zip file simply drag to application to the Applications folder.

**N.B: It's' highly recommended that you enable Gatekeeper after  run this command, by going to System Prefernces your**


## Make it start at login

If you find Night Shift Control useful and want it launched everytime you login. You can add it 
to login items by going to System Preferences -> Users & Groups -> Login Items -> click the '+' button
and find Night Shift Control

## How to build

This app depends on a private framework located at `/System/Library/PrivateFrameworks/CoreBrightness.framework`. I was 
not able to successfully build this project by adding this framework from it's original path. 
What worked is copying `CoreBrightness.framework` to a folder I owned i.e under your user directory, 
and adding that folder in Project Properties -> Build Settings -> Framework Search Paths.
