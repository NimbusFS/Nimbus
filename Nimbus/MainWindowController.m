//
//  MainWindowController.m
//  Nimbus
//
//  Created by Chris Li on 6/12/12.
//

#import "MainWindowController.h"
#import "NimbusFUSEFileSystem.h"
#import "NSAttributedString+Hyperlink.h"
#import <OSXFUSE/OSXFUSE.h>

#include <Security/Security.h>

@implementation MainWindowController

@synthesize hdDisabledImage = _hdDisabledImage;
@synthesize hdEnabledImage = _hdEnabledImage;

@synthesize hdImage = _hdImage;
@synthesize mountButton = _mountButton;
@synthesize usernameField = _usernameField;
@synthesize passwordField = _passwordField;
@synthesize loginFailedLabel = _loginFailedLabel;
@synthesize loginProgressIndicator = _loginProgressIndicator;
@synthesize creditsField = _creditsField;


- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialize the images
        NSString *hdDisabledImageFile = [NSBundle.mainBundle pathForResource:@"NimbusIconDisabled" ofType:@"png"];
        self.hdDisabledImage = [[NSImage alloc] initWithContentsOfFile: hdDisabledImageFile];
        
        NSString *hdEnabledImageFile = [NSBundle.mainBundle pathForResource:@"Nimbus" ofType:@"icns"];
        self.hdEnabledImage = [[NSImage alloc] initWithContentsOfFile:hdEnabledImageFile];
        
        isMounted = NO;
    }
    
    return self;
}

-(void)awakeFromNib
{
    [super awakeFromNib];
    
    // Subscribe to FUSE events
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(didMount:)
                   name:kGMUserFileSystemDidMount object:nil];
    [center addObserver:self selector:@selector(didUnmount:)
                   name:kGMUserFileSystemDidUnmount object:nil];
    
    // Try to pre-populate the login info
    NSArray* loginInfo = [MainWindowController getCloudAppInfoFromKeychain];
    NSString *username;
    NSString *password;
    
    if (loginInfo == nil)
    {
        [_usernameField bind:@"value"
                    toObject:[NSUserDefaultsController sharedUserDefaultsController]
                 withKeyPath:@"values.NimbusUserName"
                     options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES]
                                                         forKey:@"NSContinuouslyUpdatesValue"]];
    }
    else
    {
        username = [loginInfo objectAtIndex:0];
        password = [loginInfo objectAtIndex:1];
        [_usernameField setStringValue:username];
        [_passwordField setStringValue:password];
    }
    
            
    [_loginFailedLabel setHidden:YES];
    [_loginProgressIndicator setHidden:YES];
    
    // Credits list
    NSString *creditsPath = [NSBundle.mainBundle pathForResource:@"Credits" ofType:@"rtf"];
    [self.creditsField readRTFDFromFile:creditsPath];
}

+(NSArray *)getCloudAppInfoFromKeychain
{
    UInt32 passwordLength = 0;
    char *password = nil;
    
    SecKeychainItemRef item = nil;
    OSStatus ret = SecKeychainFindGenericPassword(NULL, 8, "CloudApp", 0, NULL, &passwordLength, (void**)&password, &item);
    
    UInt32 attributeTags[1];
    *attributeTags = kSecAccountItemAttr;
    
    UInt32 formatConstants[1];
    *formatConstants = CSSM_DB_ATTRIBUTE_FORMAT_STRING;
    
    struct SecKeychainAttributeInfo
    {
        UInt32 count;
        UInt32 *tag;
        UInt32 *format;
    } attributeInfo;
    
    attributeInfo.count = 1;
    attributeInfo.tag = attributeTags;
    attributeInfo.format = formatConstants;
    
    SecKeychainAttributeList *attributeList = nil;
    OSStatus attributeRet = SecKeychainItemCopyAttributesAndData(item, &attributeInfo, NULL, &attributeList, 0, NULL);
    
    if (attributeRet != noErr || !item)
    {
        NSLog(@"Error - %s", GetMacOSStatusErrorString(ret));
        return nil;
    }
    
    SecKeychainAttribute accountNameAttribute = attributeList->attr[0];
    NSString* accountName = [[[NSString alloc] initWithData:[NSData dataWithBytes:accountNameAttribute.data length:accountNameAttribute.length] encoding:NSUTF8StringEncoding] autorelease];
    
    NSString *passwordString = [[[NSString alloc] initWithData:[NSData dataWithBytes:password length:passwordLength] encoding:NSUTF8StringEncoding] autorelease];
    
    SecKeychainItemFreeContent(NULL, password);
    
    return [[NSArray alloc] initWithObjects:accountName, passwordString, nil];
}


#pragma mark Mounting
-(void) mount:(id)selector
{
    // we haven't yet mounted Nimbus
    if (nimbusFS == nil && [[_mountButton title] isEqualToString:@"Mount"])
    {
        [_usernameField setEnabled:NO];
        [_passwordField setEnabled:NO];
        [_mountButton setEnabled:NO];
        [_loginProgressIndicator setHidden:NO];
        
        // mount the thing
        nimbusFS = [[NimbusFUSEFileSystem alloc] initWithUsername:[_usernameField stringValue] andPassword:[_passwordField stringValue] atMountPath:@"/Volumes/Nimbus"];
        
        // mounting failed
        if (nimbusFS == nil)
        {
            [_usernameField setEnabled:YES];
            [_passwordField setEnabled:YES];
            [_mountButton setEnabled:YES];
            [_loginFailedLabel setHidden:NO];
            [_loginProgressIndicator setHidden:YES];
        }
        // mounting succeeded
        else
        {
            [_mountButton setTitle:@"Unmount"];
            [_usernameField setEnabled:NO];
            [_passwordField setEnabled:NO];
            [_mountButton setEnabled:YES];
            [_loginFailedLabel setHidden:YES];
            [_loginProgressIndicator setHidden:YES];
        }
    }
    // Nimbus is already mounted
    else
    {
        [nimbusFS unmount];
        nimbusFS = nil;
        /*
         [_mountButton setTitle:@"Mount"];        
         [_usernameField setEnabled:YES];
         [_passwordField setEnabled:YES];
         [_mountPathField setEnabled:YES];
         [_mountButton setEnabled:YES];
         [_loginFailedLabel setHidden:YES];
         [_loginProgressIndicator setHidden:YES];
         */
    }
}

- (void)didMount:(NSNotification *)notification {
    isMounted = YES;
    // Change the image
    [self.hdImage setImage:self.hdEnabledImage];
    NSDictionary* userInfo = [notification userInfo];
    NSString* mountPath = [userInfo objectForKey:kGMUserFileSystemMountPathKey];
    NSString* parentPath = [mountPath stringByDeletingLastPathComponent];
    [[NSWorkspace sharedWorkspace] selectFile:mountPath
                     inFileViewerRootedAtPath:parentPath];
}

- (void)didUnmount:(NSNotification*)notification {
    isMounted = NO;
    [self.hdImage setImage:self.hdDisabledImage];
    [_usernameField setEnabled:YES];
    [_passwordField setEnabled:YES];
    [_mountButton setEnabled:YES];
    [_mountButton setTitle:@"Mount"];
    [_loginFailedLabel setHidden:YES];
    [_loginProgressIndicator setHidden:YES];
}

#pragma mark window delegate
// Close if we aren't mounted
- (void)windowWillClose:(NSNotification *)notification 
{
    if(!isMounted){
        [NSApp terminate:self];
    }
}

@end
