//
//  AppDelegate.m
//  Nimbus
//
//  Created by Sagar Pandya on 2/2/12.
//  Copyright (c) 2012. All rights reserved.
//

#import "AppDelegate.h"

@implementation AppDelegate

@synthesize mainWindowController = _mainWindowController;

- (void)dealloc
{
    [super dealloc];
}

- (void)showWindow
{
    [self.mainWindowController showWindow:self];
    [NSApp activateIgnoringOtherApps:YES];
    [self.mainWindowController.window makeKeyAndOrderFront:self];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    //[NSApplication.sharedApplication setActivationPolicy:NSApplicationActivationPolicyAccessory];
    self.mainWindowController = [[MainWindowController alloc] initWithWindowNibName:@"MainWindow"];
    [self showWindow];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    [self showWindow];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {

    // Save changes in the application's managed object context before the application terminates.
    // [[NSNotificationCenter defaultCenter] removeObserver:self];
    
//    if (nimbusFS != nil)
//    {
//        [nimbusFS unmount];
//        nimbusFS = nil;
//    }
    
    //return NSTerminateNow;
    NSLog(@"Appl should terminate?");
    return NSTerminateCancel;
}

//- (BOOL)applicationShouldHandleReopen:(NSApplication*)theApplication hasVisibleWindows:(BOOL)flag
//{
//    [self.mainWindowController.window makeKeyAndOrderFront:self];
//    return YES;
//}

@end
