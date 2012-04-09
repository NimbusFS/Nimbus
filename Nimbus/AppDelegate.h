//
//  AppDelegate.h
//  Nimbus
//
//  Created by Sagar Pandya on 2/2/12.
//  Copyright (c) 2012. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "NimbusFUSEFileSystem.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>
{
    NimbusFUSEFileSystem *nimbusFS;
}

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSButton *mountButton;
@property (assign) IBOutlet NSTextField *usernameField;
@property (assign) IBOutlet NSSecureTextField *passwordField;
@property (assign) IBOutlet NSTextField *mountPathField;
@property (assign) IBOutlet NSTextField *loginFailedLabel;
@property (assign) IBOutlet NSProgressIndicator *loginProgressIndicator;
@property (assign) IBOutlet NSTextField *descriptionLabel;

- (IBAction)mount:(id)sender;

+(NSArray*) getCloudAppInfoFromKeychain;

@end
