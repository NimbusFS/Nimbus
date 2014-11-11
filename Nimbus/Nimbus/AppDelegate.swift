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
  // Mark this as "optional" so that we can
  // avoid initializing it in init()
  var m_engine: CLAPIEngine?
  var m_is_logged_on = false
  var m_login_failed = false

  func applicationDidFinishLaunching(aNotification: NSNotification) 
  {
    // Insert code here to initialize your application
    m_engine = CLAPIEngine(delegate: self)

    // "unwrap" the optional var with !
    m_engine!.email         = ""
    m_engine!.password      = ""
    m_engine!.clearsCookies = true

    if (self.login())
    {
      m_engine!.getItemListStartingAtPage(1, itemsPerPage: 10, userInfo: nil)
    }
  }

  func applicationWillTerminate(aNotification: NSNotification)
  {
    // Insert code here to tear down your application
  }

  func login() -> Bool
  {
    // try to get the user info (this is asynchronous)
    m_engine!.getAccountInformationWithUserInfo(nil)

    // create a timer to wait a max amount of time
    var timeoutDate: NSDate = NSDate(timeIntervalSinceNow: 15.0)

    // wait until it succeeds
    while (!m_is_logged_on && timeoutDate.timeIntervalSinceNow > 0)
    {
      var stopDate = NSDate(timeIntervalSinceNow: 0.5)
      var runLoop = NSRunLoop.currentRunLoop()
      runLoop.runUntilDate(stopDate)

      if (m_login_failed)
      {
        m_is_logged_on = false
        return false
      }
    }

    return m_is_logged_on
  }

  func accountInformationRetrievalSucceeded(account: CLAccount, connectionIdentifier: NSString, userInfo: AnyObject)
  {
    m_is_logged_on = true
  }

  func requestDidFailWithError(error: NSError, connectionIdentifier: NSString, userInfo: AnyObject)
  {
    NSLog("Failure: %@, %@", connectionIdentifier, error)

    if (!m_is_logged_on)
    {
      m_login_failed = true
    }
  }

  func itemListRetrievalSucceeded(items: NSArray, connectionIdentifier: NSString, userInfo: AnyObject)
  {
    for item in items
    {
      NSLog("%@", item.name)
    }
  }
}

