//
//  AppDelegate.m
//  Nimbus
//
//  Created by Sagar Pandya on 2/2/12.
//  Copyright (c) 2012. All rights reserved.
//

#import "AppDelegate.h"
#import "NimbusFUSEFileSystem.h"
#import "NSAttributedString+Hyperlink.h"
#import <OSXFUSE/OSXFUSE.h>

#include <Security/Security.h>

@implementation AppDelegate

@synthesize window = _window;
@synthesize mountButton = _mountButton;
@synthesize usernameField = _usernameField;
@synthesize passwordField = _passwordField;
@synthesize mountPathField = _mountPathField;
@synthesize descriptionLabel = _descriptionLabel;
@synthesize loginFailedLabel = _loginFailedLabel;
@synthesize loginProgressIndicator = _loginProgressIndicator;

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

- (void)dealloc
{
    [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(didMount:)
                   name:kGMUserFileSystemDidMount object:nil];
    [center addObserver:self selector:@selector(didUnmount:)
                   name:kGMUserFileSystemDidUnmount object:nil];
    
    NSArray* loginInfo = [AppDelegate getCloudAppInfoFromKeychain];
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
    
    [_mountPathField bind:@"value"
                 toObject:[NSUserDefaultsController sharedUserDefaultsController]
              withKeyPath:@"values.NimbusMountPath"
                  options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES]
                                                      forKey:@"NSContinuouslyUpdatesValue"]];    
    
    [_descriptionLabel setAllowsEditingTextAttributes: YES];
    [_descriptionLabel setSelectable: YES];
    
    NSURL* url = [NSURL URLWithString:@"http://getcloudapp.com"];
    
    NSMutableAttributedString* string = [[NSMutableAttributedString alloc] initWithString:@"Get a CloudApp account at "];
    [string appendAttributedString:[NSAttributedString hyperlinkFromString:@"www.getcloudapp.com" withURL:url]];
    [string appendAttributedString:[[NSAttributedString alloc] initWithString:@". Then sign in below."]];
    
    NSDictionary *attributes = [[NSDictionary alloc] initWithObjectsAndKeys:
                                [NSFont fontWithName:@"Lucida Grande" size:13], NSFontAttributeName,
                                nil];
    NSRange range = NSMakeRange(0, [string length]);
    [string addAttributes:attributes range:range];
    
    [_descriptionLabel setAttributedStringValue:string];
    [_loginFailedLabel setHidden:YES];
    [_loginProgressIndicator setHidden:YES];
}

-(void) mount:(id)selector
{
    // we haven't yet mounted Nimbus
    if (nimbusFS == nil && [[_mountButton title] isEqualToString:@"Mount"])
    {
        [_usernameField setEnabled:NO];
        [_passwordField setEnabled:NO];
        [_mountPathField setEnabled:NO];
        [_mountButton setEnabled:NO];
        [_loginProgressIndicator setHidden:NO];

        // mount the thing
        nimbusFS = [[NimbusFUSEFileSystem alloc] initWithUsername:[_usernameField stringValue] andPassword:[_passwordField stringValue] atMountPath:[_mountPathField stringValue]];
        
        // mounting failed
        if (nimbusFS == nil)
        {
            [_usernameField setEnabled:YES];
            [_passwordField setEnabled:YES];
            [_mountPathField setEnabled:YES];
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
            [_mountPathField setEnabled:NO];
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
    NSDictionary* userInfo = [notification userInfo];
    NSString* mountPath = [userInfo objectForKey:kGMUserFileSystemMountPathKey];
    NSString* parentPath = [mountPath stringByDeletingLastPathComponent];
    [[NSWorkspace sharedWorkspace] selectFile:mountPath
                     inFileViewerRootedAtPath:parentPath];
}

- (void)didUnmount:(NSNotification*)notification {
    [_usernameField setEnabled:YES];
    [_passwordField setEnabled:YES];
    [_mountButton setEnabled:YES];
    [_mountButton setTitle:@"Mount"];
    [_mountPathField setEnabled:YES];
    [_loginFailedLabel setHidden:YES];
    [_loginProgressIndicator setHidden:YES];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {

    // Save changes in the application's managed object context before the application terminates.
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (nimbusFS != nil)
    {
        [nimbusFS unmount];
        nimbusFS = nil;
    }
    
    return NSTerminateNow;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication*)theApplication hasVisibleWindows:(BOOL)flag
{
    [_window makeKeyAndOrderFront:self];
    return YES;
}

@end
