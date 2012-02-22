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
#import "NSError+POSIX.h"
#import <OSXFUSE/OSXFUSE.h>

@implementation NimbusFUSEFileSystem
@synthesize cloudFiles;
@synthesize cachePath;
@synthesize engine_;

BOOL hasMorePages = YES;
NSInteger whichPage = 1;

- (NimbusFUSEFileSystem *) initWithUsername:(NSString *)username andPassword:(NSString *)password atMountPath:(NSString *)mountPath
{
    self = [super init];
    if (!self) return nil;
    
    self.engine_ = [CLAPIEngine engineWithDelegate:self];
	engine_.email = username;
	engine_.password = password;
    
    fs_ = [[GMUserFileSystem alloc] initWithDelegate:self isThreadSafe:YES];
    
    NSMutableArray* options = [NSMutableArray array];
    //[options addObject:@"rdwr"];
    [options addObject:@"volname=NimbusFS"];
    [options addObject:[NSString stringWithFormat:@"volicon=%@", 
                        [[NSBundle mainBundle] pathForResource:@"Fuse" ofType:@"icns"]]];
    [fs_ mountAtPath:mountPath withOptions:options];
    
    cloudFiles = [[NSMutableDictionary alloc] init];
    cachePath = @"/Users/sagar/Library/Application Support/Nimbus/Cache/";
    [[NSFileManager defaultManager] createDirectoryAtPath:cachePath withIntermediateDirectories:YES attributes:nil error:nil];
   
    [self getNextPage];
    
    return self;
}

- (void) getNextPage
{
    //NSLog(@"Getting page %ld", whichPage);
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
    @synchronized(self)
    {
        return [cloudFiles allKeys];
    }
}

- (NSData *)contentsAtPath:(NSString *)path
{
    @synchronized(self)
    {
        //NSLog(@"request for contents for path: %@", path);
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
    NSLog(@"Renaming item: %@ --> %@", source, destination);
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
    NSLog(@"Changing name to %@", newname);
    NSString *ident = [engine_ changeNameOfItem:item toName:newname userInfo:nil];

    // 2. rename in the disk cache
    [file renameInCache:newname];

    // 3. rename in the memory cache (associative array of NimbusFile objects)
    [cloudFiles removeObjectForKey:[source lastPathComponent]];
    
    if ([cloudFiles objectForKey:[source lastPathComponent]] != nil)
        NSLog(@"Deletion failed...");
    
    [cloudFiles setObject:file forKey:newname];

    return YES;
}

- (BOOL)removeItemAtPath:(NSString *)path error:(NSError **)error
{
    @synchronized(self)
    {
        NimbusFile *file = [cloudFiles objectForKey:[path lastPathComponent]];
        CLWebItem *item = [file itsCLWebItem];
        
        NSLog(@"Removing file %@ with href=%@", path, item.href);
                
        if (file == nil || item == nil)
        {
            NSLog(@"File not found in cache");
            return NO;
        }

        [engine_ deleteItem:item userInfo:nil];

        [cloudFiles removeObjectForKey:[path lastPathComponent]];
        
        return YES;
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    NSLog(@"REsponse status: %@", [(NSHTTPURLResponse *)response statusCode]); 
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    // Append the new data to receivedData.
    // receivedData is an instance variable declared elsewhere.
    NSLog(@"Data: %@", data);
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
    int mode = 0700;
    BOOL isDirectory;

    if ([path isEqualToString:@"/"])
        isDirectory = YES;

    NSMutableDictionary *attr = [NSDictionary dictionaryWithObjectsAndKeys:
         [NSNumber numberWithInt:mode], NSFilePosixPermissions,
         [NSNumber numberWithInt:geteuid()], NSFileOwnerAccountID,
         [NSNumber numberWithInt:getegid()], NSFileGroupOwnerAccountID,
         [NSDate date], NSFileCreationDate,
         [NSDate date], NSFileModificationDate,
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

- (NSDictionary *)finderAttributesAtPath:(NSString *)path error:(NSError **)error
{
    return [self resourceAttributesAtPath:path error:error];
}

- (NSDictionary*)resourceAttributesAtPath:(NSString *)path error:(NSError **)error
{
    return nil;
}

#pragma CLAPI callbacks
-(void) itemUpdateDidSucceed:(CLWebItem *)resultItem connectionIdentifier:(NSString *)connectionIdentifier userInfo:(id)userInfo
{
    NSLog(@"[SUCCESS]: %@", connectionIdentifier);
}

- (void)requestDidFailWithError:(NSError *)error connectionIdentifier:(NSString *)connectionIdentifier userInfo:(id)userInfo {
	NSLog(@"[FAIL]: %@, %@", connectionIdentifier, error);
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
            NimbusFile *theFile = [[NimbusFile alloc] initWithWebItem:item andCachePath:cachePath];
            [theFile download];
            [cloudFiles setObject:theFile forKey:[item name]];
        }
        whichPage++;
        
        if ( hasMorePages )
            [self getNextPage];
    }
}

@end
