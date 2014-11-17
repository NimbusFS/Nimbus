class CloudApp: NSObject, CLAPIEngineDelegate
{
  var m_engine: CLAPIEngine?
  var m_is_logged_in = false
  var m_login_failed = false

  func login(username: NSString, password: NSString) -> Bool
  {
    // Log into CloudApp. Return true if success, false on failure
    m_engine                = CLAPIEngine(delegate: self)
    m_engine!.email         = username
    m_engine!.password      = password
    m_engine!.clearsCookies = true

    // try to get user info from CloudApp (this is an asynchronous call)
    m_engine!.getAccountInformationWithUserInfo(nil)

    // wait at most 5 seconds for a login to succeed or fail
    var timeoutDate: NSDate = NSDate(timeIntervalSinceNow: 5.0)
    while (!m_is_logged_in && timeoutDate.timeIntervalSinceNow > 0)
    {
      // Sleep for 0.5s
      var stopDate = NSDate(timeIntervalSinceNow: 0.5)
      var runLoop  = NSRunLoop.currentRunLoop()
      runLoop.runUntilDate(stopDate)

      // check if login succeeded
      if (m_login_failed)
      {
        m_is_logged_in = false
        return false
      }
    }

    return true;
  }

  func requestFiles()
  {
    NSLog("requestFiles")
    NSLog(m_engine!.getItemListStartingAtPage(1, itemsPerPage: 10, userInfo: nil))
  }

  // CLAPIEngine callbacks below
  func requestDidSucceedWithConnectionIdentifier(connectionIdentifier: NSString, userInfo: AnyObject)
  {
    NSLog("requestDidSucceedWithConnectionIdentifier")
  }

  // HTTP request failed
  func requestDidFailWithError(error: NSError, connectionIdentifier: NSString, userInfo: AnyObject)
  {
    NSLog("requestDidFailWithError")

    if m_is_logged_in
    {
      //
    }
    else
    {
      m_login_failed = true
    }
  }

  // Successfully got account info from CloudApp (ie. login succeeded)
  func accountInformationRetrievalSucceeded(account: CLAccount, connectionIdentifier: NSString, userInfo: AnyObject)
  {
    m_is_logged_in = true
    m_login_failed = false
  }

  // Successfully retrieved a list of files from CloudApp
  func itemListRetrievalSucceeded(items: NSArray, connectionIdentifier: NSString, userInfo: AnyObject)
  {
    NSLog("itemListRetrievalSucceeded")

    for item in items
    {
      NSLog(item.name)
    }
  }

  // And the rest
  func fileUploadDidProgress(percentageComplete: CGFloat, connectionIdentifier: NSString, userInfo: AnyObject)
  {
    NSLog("fileUploadDidProgress")
  }

  func fileUploadDidSucceedWithResultingItem(item: CLWebItem, connectionIdentifier: NSString, userInfo: AnyObject)
  {
    NSLog("fileUploadDidSucceedWithResultingItem")
  }

  func linkBookmarkDidSucceedWithResultingItem(item: CLWebItem, connectionIdentifier: NSString, userInfo: AnyObject)
  {
    NSLog("linkBookmarkDidSucceedWithResultingItem")
  }

  func accountUpdateDidSucceed(account: CLAccount, connectionIdentifier: NSString, userInfo: AnyObject)
  {
    NSLog("accountUpdateDidSucceed")
  }

  func itemUpdateDidSucceed(item: CLWebItem, connectionIdentifier: NSString, userInfo: AnyObject)
  {
    NSLog("itemUpdateDidSucceed")
  }

  func itemDeletionDidSucceed(item: CLWebItem, connectionIdentifier: NSString, userInfo: AnyObject)
  {
    NSLog("itemDeletionDidSucceed")
  }

  func itemRestorationDidSucceed(item: CLWebItem, connectionIdentifier: NSString, userInfo: AnyObject)
  {
    NSLog("itemRestorationDidSucceed")
  }

  func itemInformationRetrievalSucceeded(item: CLWebItem, connectionIdentifier: NSString, userInfo: AnyObject)
  {
    NSLog("itemInformationRetrievalSucceeded")
  }

  func accountCreationSucceeded(newAccount: CLAccount, connectionIdentifier: NSString, userInfo: AnyObject)
  {
    NSLog("accountCreationSucceeded")
  }

  func storeProductInformationRetrievalSucceeded(productIdentifiers: NSArray, connectionIdentifier: NSString, userInfo: AnyObject)
  {
    NSLog("storeProductInformationRetrievalSucceeded")
  }

  func storeReceiptRedemptionSucceeded(account: CLAccount, connectionIdentifier: NSString, userInfo: AnyObject)
  {
    NSLog("storeReceiptRedemptionSucceeded")
  }
}
