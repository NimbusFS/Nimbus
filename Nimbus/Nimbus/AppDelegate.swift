//
//  AppDelegate.swift
//  Nimbus
//
//  Created by Sagar Pandya on 11/10/14.
//  Copyright (c) 2014 Sagar Pandya. All rights reserved.
//
import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, CLAPIEngineDelegate 
{
  func applicationDidFinishLaunching(aNotification: NSNotification) 
  {
    // Insert code here to initialize your application
    var cloudApp  = CloudApp()
    var logged_in = cloudApp.login("sagargp@gmail.com", password:"wetfeet")

    if logged_in
    {
      NSLog("Success!")
      cloudApp.requestFiles()
    }
  }

  func applicationWillTerminate(aNotification: NSNotification)
  {
    // Insert code here to tear down your application
  }
}
