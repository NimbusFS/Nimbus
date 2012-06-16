//
//  AppDelegate.h
//  Nimbus
//
//  Created by Sagar Pandya on 2/2/12.
//  Copyright (c) 2012. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "NimbusFUSEFileSystem.h"
#import "MainWindowController.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>
{
    MainWindowController *window;
}

@property (assign) IBOutlet NSWindow *window;

@end
