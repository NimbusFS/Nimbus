//
//  MainWindowController.h
//  Nimbus
//
//  Created by Chris Li on 6/12/12.
//

#import <Cocoa/Cocoa.h>
#import "NimbusFUSEFileSystem.h"

@interface MainWindowController : NSWindowController {
    NimbusFUSEFileSystem *nimbusFS;
}

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
