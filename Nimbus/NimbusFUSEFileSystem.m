//
//  NimbusFUSEFileSystem.m
//  Nimbus
//
//  Created by Sagar Pandya on 2/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "NimbusFUSEFileSystem.h"
#import "Cloud.h"
#import <OSXFUSE/OSXFUSE.h>

@implementation NimbusFUSEFileSystem
@synthesize cloudFiles;

- (NimbusFUSEFileSystem *) initWithUsername:(NSString *)username andPassword:(NSString *)password atMountPath:(NSString *)mountPath
{
    self = [super init];
    if (!self) return nil;
    
    // blah
    engine_ = [CLAPIEngine engineWithDelegate:self];
	engine_.email = username;
	engine_.password = password;
    
    fs_ = [[GMUserFileSystem alloc] initWithDelegate:self isThreadSafe:YES];
    
    NSMutableArray* options = [NSMutableArray array];
    [options addObject:@"rdonly"];
    [options addObject:@"volname=NimbusFS"];
    [options addObject:[NSString stringWithFormat:@"volicon=%@", 
                        [[NSBundle mainBundle] pathForResource:@"Fuse" ofType:@"icns"]]];
    [fs_ mountAtPath:mountPath withOptions:options];
    
    self.cloudFiles = [[NSMutableDictionary alloc] init];
    
    [engine_ getItemListStartingAtPage:40 itemsPerPage:10 userInfo:nil];
    
    return self;
}

- (void) dealloc
{
    [fs_ unmount];  // Just in case we need to unmount;
    [[fs_ delegate] release];  // Clean up HelloFS
    [fs_ release];
}

#pragma mark == Overridden GMUserFileSystem delegate methods
- (NSArray *)contentsOfDirectoryAtPath:(NSString *)path error:(NSError **)error {
    return [cloudFiles allKeys];
}

- (NSData *)contentsAtPath:(NSString *)path
{
    NSLog(@"request for contents for path: %@", path);
    if ( [cloudFiles objectForKey:[path lastPathComponent]] == nil )
        return nil;
    
    return [cloudFiles objectForKey:[path lastPathComponent]];
    //return [[NSData alloc] initWithContentsOfURL:[cloudFiles objectForKey:[path lastPathComponent]]];
}

#pragma CLAPI callbacks
- (void)requestDidFailWithError:(NSError *)error connectionIdentifier:(NSString *)connectionIdentifier userInfo:(id)userInfo {
	NSLog(@"[FAIL]: %@, %@", connectionIdentifier, error);
}

- (void)itemListRetrievalSucceeded:(NSArray *)items connectionIdentifier:(NSString *)connectionIdentifier userInfo:(id)userInfo
{
    if ( [items count] == 0 )
        return;
    
	NSLog(@"[ITEM LIST]: %@, %@", connectionIdentifier, items);
    for (CLWebItem *item in items)
    {
        NSLog(@"inserting into dictionary: %@", [item name]);
        //[cloudFiles setObject:[item thumb] forKey:[item name]];
        [cloudFiles setObject:[[NSData alloc] initWithContentsOfURL:[item remoteURL]] forKey:[item name]];
    }
}

@end
