//
//  main.swift
//  Nimbus
//
//  Created by Sagar Pandya on 11/15/14.
//  Copyright (c) 2014 Sagar Pandya. All rights reserved.
//

import Foundation

var cloudApp  = CloudApp()
var logged_in = cloudApp.login("sagargp@gmail.com", password:"wetfeet")

if logged_in
{
  NSLog("Success!")
  cloudApp.requestFiles()
  sleep(10)
}
