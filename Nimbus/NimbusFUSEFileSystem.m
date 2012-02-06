//
//  NimbusFUSEFileSystem.m
//  Nimbus
//
//  Created by Sagar Pandya on 2/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "NimbusFUSEFileSystem.h"
#import "NimbusFile.h"
#import "Cloud.h"
#import <OSXFUSE/OSXFUSE.h>

@implementation NimbusFUSEFileSystem
@synthesize cloudFiles;
@synthesize cachePath;

BOOL hasMorePages = YES;
NSInteger whichPage = 1;

- (NimbusFUSEFileSystem *) initWithUsername:(NSString *)username andPassword:(NSString *)password atMountPath:(NSString *)mountPath
{
    self = [super init];
    if (!self) return nil;
    
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
    
    cloudFiles = [[NSMutableDictionary alloc] init];
    cachePath = @"/Users/sagar/Library/Application Support/Nimbus/Cache/";
    [[NSFileManager defaultManager] createDirectoryAtPath:cachePath withIntermediateDirectories:YES attributes:nil error:nil];
   
    //[engine_ getItemListStartingAtPage:1 itemsPerPage:10 userInfo:nil];
    [self getNextPage];
    
    return self;
}

- (void) getNextPage
{
    NSLog(@"Getting page %ld", whichPage);
    [engine_ getItemListStartingAtPage:whichPage itemsPerPage:10 userInfo:nil];
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
    
    // return the data from the cache
    // basically get the filename, lookup its cache path, open that file, and return its data
    NimbusFile *theFile = [cloudFiles objectForKey:[path lastPathComponent]];
    if ([theFile isCachedToDisk])
    {
        [theFile cacheToMemory];
        return [theFile data];
    }
    else
    {
        NSLog(@"File wasn't cached! (%@)", path);
        return nil;
    }
}

#pragma CLAPI callbacks
- (void)requestDidFailWithError:(NSError *)error connectionIdentifier:(NSString *)connectionIdentifier userInfo:(id)userInfo {
	NSLog(@"[FAIL]: %@, %@", connectionIdentifier, error);
}

- (void)itemListRetrievalSucceeded:(NSArray *)items connectionIdentifier:(NSString *)connectionIdentifier userInfo:(id)userInfo
{
    if ( [items count] == 0 )
    {
        hasMorePages = NO;
        return;
    }
    
    if ( [items count] < 10 )
        hasMorePages = NO;
    
    // get the data from these pages
    NSLog(@"[ITEM LIST]: %@, %@", connectionIdentifier, items);
    for (CLWebItem *item in items)
    {
        NSLog(@"inserting into dictionary: %@", [item name]);
        NimbusFile *theFile = [[NimbusFile alloc] initWithWebItem:item andCachePath:cachePath];
        [theFile download];
        [cloudFiles setObject:theFile forKey:[item name]];
    }
    whichPage++;
    
    if ( hasMorePages )
        [self getNextPage];
}

@end
