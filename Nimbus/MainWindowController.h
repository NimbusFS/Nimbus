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

// Store two different images to switch between
@property (retain,nonatomic) NSImage *hdDisabledImage;
@property (retain,nonatomic) NSImage *hdEnabledImage;

@property (retain,nonatomic) IBOutlet NSImageView *hdImage;

@property (retain,nonatomic) IBOutlet NSButton *mountButton;
@property (retain,nonatomic) IBOutlet NSTextField *usernameField;
@property (retain,nonatomic) IBOutlet NSSecureTextField *passwordField;
@property (retain,nonatomic) IBOutlet NSTextField *loginFailedLabel;
@property (retain,nonatomic) IBOutlet NSProgressIndicator *loginProgressIndicator;

@property (retain,nonatomic) IBOutlet NSTextView *creditsField;

- (IBAction)mount:(id)sender;

+(NSArray*) getCloudAppInfoFromKeychain;

@end
