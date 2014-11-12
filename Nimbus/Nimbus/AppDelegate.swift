//
//  AppDelegate.swift
//  Nimbus
//
//  Created by Sagar Pandya on 11/10/14.
//  Copyright (c) 2014 Sagar Pandya. All rights reserved.
//
import Cocoa

class CloudApp: NSObject, CLAPIEngineDelegate
{
  var m_engine: CLAPIEngine
  var m_is_logged_in = false
  var m_login_failed = false

  func login(username: NSString, password: NSString) -> Bool
  {
    // Log into CloudApp. Return true if success, false on failure
    m_engine               = CLAPIEngine(delegate: self)
    m_engine.email         = username
    m_engine.password      = password
    m_engine.clearsCookies = true

    // try to get user info from CloudApp (this is an asynchronous call)
    m_engine.getAccountInformationWithUserInfo(nil)

    // wait at most 5 seconds for a login to succeed or fail
    var timeoutDate: NSDate = NSDate(timeIntervalSinceNow: 5.0)
    while (!m_is_logged_on && timeoutDate.timeIntervalSinceNow > 0)
    {
      // Sleep for 0.5s
      var stopDate = NSDate(timeIntervalSinceNow: 0.5)
      var runLoop  = NSRunLoop.currentRunLoop()
      runLoop.runUntilDate(stopDate)

      // check if login succeeded
      if (m_login_failed)
      {
        m_is_logged_on = false
        return false
      }
    }

    return true;
  }

  // CLAPI callbacks below

  // Successfully got account info from CloudApp (ie. login succeeded)
  func accountInformationRetrievalSucceeded(account: CLAccount, connectionIdentifier: NSString, userInfo: AnyObject)
  {
    m_is_logged_on = true
    m_login_failed = false
  }

  // HTTP request failed
  func requestDidFailWithError(error: NSError, connectionIdentifier: NSString, userInfo: AnyObject)
  {
    if m_is_logged_on
    {
      // a non-login related request failed
    }
    else
    {
      m_login_failed = true
    }
  }

  // Successfully retrieved a list of files from CloudApp
  func itemListRetrievalSucceeded(items: NSArray, connectionIdentifier: NSString, userInfo: AnyObject)
  {
    for item in items
    {
      NSLog(item.name)
    }
  }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, CLAPIEngineDelegate 
{
  func applicationDidFinishLaunching(aNotification: NSNotification) 
  {
    // Insert code here to initialize your application
    var cloudApp: CloudApp
    cloudApp.login()
  }

  func applicationWillTerminate(aNotification: NSNotification)
  {
    // Insert code here to tear down your application
  }
}
