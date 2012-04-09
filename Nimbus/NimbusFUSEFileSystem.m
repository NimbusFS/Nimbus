//
//  NimbusFUSEFileSystem.m
//  Nimbus
//
//  Created by Sagar Pandya on 2/2/12.
//  Copyright (c) 2012. All rights reserved.
//

#import "NimbusFUSEFileSystem.h"
#import "NimbusFile.h"
#import "Cloud.h"
#import "NSError+POSIX.h"
#import <OSXFUSE/OSXFUSE.h>

@implementation NimbusFUSEFileSystem
@synthesize cloudFiles;
@synthesize cachePath;
@synthesize engine_;
@synthesize whichPage;
@synthesize hasMorePages;
@synthesize isLoggedIn;


- (NimbusFUSEFileSystem *) initWithUsername:(NSString *)username andPassword:(NSString *)password atMountPath:(NSString *)mountPath
{
    self = [super init];
    if (!self) return nil;
    
    // initialize the Cloud API engine
    self.engine_ = [CLAPIEngine engineWithDelegate:self];
	engine_.email = username;
	engine_.password = password;
    engine_.clearsCookies = YES;
    
    if ([self login])
    {
        NSLog(@"Login succeeded");
        // initialize the local caches of files in the Cloud Account
        cloudFiles = [[NSMutableDictionary alloc] init];
        cachePath = [[NSString alloc] initWithFormat:@"%@/Library/Application Support/Nimbus/Cache.%@", NSHomeDirectory(), username];
        [[NSFileManager defaultManager] createDirectoryAtPath:cachePath withIntermediateDirectories:YES attributes:nil error:nil];
        
        isLoggedIn = NO;
        hasMorePages = YES;
        whichPage = 1;
        
        // initialize the FUSE filesystem object
        fs_ = [[GMUserFileSystem alloc] initWithDelegate:self isThreadSafe:YES];
        
        NSMutableArray* options = [NSMutableArray array];
        [options addObject:@"volname=NimbusFS"];
        [options addObject:[NSString stringWithFormat:@"volicon=%@", [[NSBundle mainBundle] pathForResource:@"Nimbus" ofType:@"icns"]]];
        [fs_ mountAtPath:mountPath withOptions:options];

        // refresh the listing every 30 seconds
        [NSTimer scheduledTimerWithTimeInterval:30.0 target:self selector:@selector(refreshFiles) userInfo:nil repeats:YES];
    
        [self getNextPage];
        return self;
    }
    else
    {
        NSLog(@"Login failed");
        return nil;
    }
}

- (void) unmount
{
    [self dealloc];
}

- (BOOL) login
{
    // try to get user info
    // wait until it succeeds or fails
    [engine_ getAccountInformationWithUserInfo:nil];
    
    NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:15.0]; // 15 second timeout

    while (!isLoggedIn && [timeoutDate timeIntervalSinceNow] > 0)
    {
        NSDate *stopDate = [NSDate dateWithTimeIntervalSinceNow:0.5];
        [[NSRunLoop currentRunLoop] runUntilDate:stopDate];
        
        if (loginFailed)
        {
            isLoggedIn = NO;
            break;
        }
    }
    return isLoggedIn;
}

- (void) getNextPage
{
    [engine_ getItemListStartingAtPage:whichPage itemsPerPage:10 userInfo:nil];
}

-(void) refreshFiles
{
    @synchronized(self)
    {
        if (hasMorePages)
            return;
        
        hasMorePages = YES;
        whichPage = 1;
        [self getNextPage];
    }
}

- (void) dealloc
{
    [fs_ unmount];  // Just in case we need to unmount;
    [[fs_ delegate] release];  // Clean up HelloFS
    [fs_ release];
}

#pragma mark == Overridden GMUserFileSystem delegate methods
- (NSArray *)contentsOfDirectoryAtPath:(NSString *)path error:(NSError **)error {
    @synchronized(self)
    {
        return [cloudFiles allKeys];
    }
}

- (NSData *)contentsAtPath:(NSString *)path
{
    @synchronized(self)
    {
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
}

- (BOOL)moveItemAtPath:(NSString *)source toPath:(NSString *)destination error:(NSError **)error
{
    @synchronized(self)
    {
        NSLog(@"Renaming...");
        NSString *newname = [destination lastPathComponent];

        NimbusFile *file = [cloudFiles objectForKey:[source lastPathComponent]];
        CLWebItem *item = [[file itsCLWebItem] retain];

        if (item == nil)
        {
           NSLog(@"Item is nil");
           return NO;
        }

        // this is dirty. assume the move was successful :(
        // steps to rename
        // 1. rename at cloudapp
        [engine_ changeNameOfItem:item toName:newname userInfo:nil];

        // 2. remove from the local cache
        [cloudFiles removeObjectForKey:[source lastPathComponent]];
        
        // 3. readd to the cache with a new key
        [cloudFiles setObject:file forKey:[destination lastPathComponent]];
        
        // 4. rename the file in the disk cache
        [file renameInCache:[destination lastPathComponent]];
        return YES;
    }
}

- (BOOL)removeItemAtPath:(NSString *)path error:(NSError **)error
{
    @synchronized(self)
    {
        NSLog(@"Removing...");
        NimbusFile *file = [cloudFiles objectForKey:[path lastPathComponent]];
        CLWebItem *item = [file itsCLWebItem];
        
        if (file == nil || item == nil)
        {
            NSLog(@"File not found in cache");
            return NO;
        }

        [engine_ deleteItem:item userInfo:nil];
        [cloudFiles removeObjectForKey:[path lastPathComponent]];
        [file dealloc];
        return YES;
    }
}

- (NSDictionary *)attributesOfItemAtPath:(NSString *)path userData:(id)userData error:(NSError **)error
{
    if (!path)
    {
        if (error)
            *error = [NSError errorWithPOSIXCode:EINVAL];
        NSLog(@"Bad path!");
        return nil;
    }
    
    @synchronized(self)
    {
        NSDate *creationDate;
        NSDate *modificationDate;
        
        int mode = 0700;
        BOOL isDirectory = NO;
        
        if ([path isEqualToString:@"/"])
        {
            isDirectory = YES;
            creationDate = [NSDate date];
            modificationDate = [NSDate date];
        } else {
            NimbusFile *file = [cloudFiles objectForKey:[path lastPathComponent]];

            if (file == nil)
                return nil;
            
            CLWebItem *item = file.itsCLWebItem;
            creationDate = [item createdAt];
            modificationDate = [item updatedAt];
        }
        
        NSMutableDictionary *attr = [NSDictionary dictionaryWithObjectsAndKeys:
             [NSNumber numberWithInt:mode], NSFilePosixPermissions,
             [NSNumber numberWithInt:geteuid()], NSFileOwnerAccountID,
             [NSNumber numberWithInt:getegid()], NSFileGroupOwnerAccountID,
             creationDate, NSFileCreationDate,
             modificationDate, NSFileModificationDate,
             (isDirectory ? NSFileTypeDirectory : NSFileTypeRegular), NSFileType,
             nil];
        
        if (!attr)
        {
            if (error)
                *error = [NSError errorWithPOSIXCode:ENOENT];
            NSLog(@"Attrs not set!");
        }
        return attr;
    }
}

#pragma CLAPI callbacks
- (void)accountInformationRetrievalSucceeded:(CLAccount *)account connectionIdentifier:(NSString *)connectionIdentifier userInfo:(id)userInfo
{
    isLoggedIn = YES;
}

-(void) itemUpdateDidSucceed:(CLWebItem *)resultItem connectionIdentifier:(NSString *)connectionIdentifier userInfo:(id)userInfo
{
    // cool
}

-(void) itemDeletionDidSucceed:(CLWebItem *)resultItem connectionIdentifier:(NSString *)connectionIdentifier userInfo:(id)userInfo
{
    // neato
    NSLog(@"Deletion succeeded.");
}

- (void)itemListRetrievalSucceeded:(NSArray *)items connectionIdentifier:(NSString *)connectionIdentifier userInfo:(id)userInfo
{
    @synchronized(self)
    {
        if ( [items count] == 0 )
        {
            hasMorePages = NO;
            return;
        }
        
        if ( [items count] < 10 )
            hasMorePages = NO;
        
        // get the data from these pages
        for (CLWebItem *item in items)
        {
            if ([cloudFiles objectForKey:[item name]] == nil)
            {
                NimbusFile *theFile = [[NimbusFile alloc] initWithWebItem:item andCachePath:cachePath];
                [theFile download];
                [cloudFiles setObject:theFile forKey:[item name]];
            }
        }
        whichPage++;
        
        if ( hasMorePages )
            [self getNextPage];
    }
}

- (void)requestDidFailWithError:(NSError *)error connectionIdentifier:(NSString *)connectionIdentifier userInfo:(id)userInfo {
	NSLog(@"[FAIL]: %@, %@", connectionIdentifier, error);
    
    if (!isLoggedIn)
        loginFailed = YES;
    
    if (isLoggedIn)
        [self refreshFiles];
}

@end
