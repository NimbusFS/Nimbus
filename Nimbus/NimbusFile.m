//
//  NimbusFile.m
//  Nimbus
//
//  Created by Sagar Pandya on 2/5/12.
//  Copyright (c) 2012. All rights reserved.
//

#import "NimbusFile.h"

@implementation NimbusFile

@synthesize itsCLWebItem;
@synthesize itsDiskPath;
@synthesize itsCachePath;
@synthesize isCachedToDisk;
@synthesize isCachedInMemory;
@synthesize data;
- (NSFileHandle*) fileHandle
{
    if (itsFileHandle == nil) {
        itsFileHandle = [NSFileHandle fileHandleForWritingAtPath:itsDiskPath];
        if(itsFileHandle == nil) {
            // Then the file must not exist yet
            [[NSFileManager defaultManager] createFileAtPath:itsDiskPath contents:nil attributes:nil];
            currentOffset = 0ULL;
            itsFileHandle = [NSFileHandle fileHandleForWritingAtPath:itsDiskPath];
        }
    }
    return [itsFileHandle retain];
}
- (NSMutableDictionary*) attributes 
{
    // Get file size
    NSDictionary *cacheAttr = [[NSFileManager defaultManager] attributesOfItemAtPath:itsDiskPath
                                                                               error:nil];
    unsigned long long fileSize = [[cacheAttr objectForKey:NSFileSize] unsignedLongLongValue];
    
    [itsAttributes setObject: [NSNumber numberWithUnsignedLongLong:fileSize] forKey:NSFileSize];
    return itsAttributes;
}

- (NimbusFile *) initWithWebItem:(CLWebItem *)webItem andCachePath:(NSString *)path
{
    self = [super init];
    if (!self) return nil;
    
    itsFileHandle = nil;
    itsCLWebItem = [webItem retain];
    itsCachePath = [path retain];
    itsDiskPath = [[NSString alloc] initWithFormat:@"%@/%@", path, [[webItem name] lastPathComponent]];
    
    // TODO: Check mtimes
    if ([[NSFileManager defaultManager] fileExistsAtPath:itsDiskPath]) {
        isCachedToDisk = YES;
    } else {
        isCachedToDisk = NO;
    }
    
    isCachedInMemory = NO;
    
    itsAttributes = [[NSMutableDictionary alloc] initWithObjectsAndKeys: 
                     [NSNumber numberWithUnsignedLongLong:0], NSFileSize, 
                     [NSNumber numberWithInt:0700], NSFilePosixPermissions, 
                     [NSNumber numberWithInt:geteuid()], NSFileOwnerAccountID,
                     [NSNumber numberWithInt:getegid()], NSFileGroupOwnerAccountID,
                     [itsCLWebItem createdAt], NSFileCreationDate,
                     [itsCLWebItem updatedAt], NSFileModificationDate,
                     NSFileTypeRegular, NSFileType,
                     nil];
    
    return self;
}

- (NimbusFile*) initWithName:(NSString*)aName andCachePath:(NSString*)aPath
{
    self = [super init];
    if (!self) return nil;
    
    itsFileHandle = nil;
    itsCLWebItem = [[CLWebItem alloc] initWithName:aName];
    itsCachePath = aPath;
    itsDiskPath = [[NSString alloc] initWithFormat:@"%@/%@", itsCachePath, aName];
    [[NSFileManager defaultManager] createFileAtPath:itsDiskPath contents:nil attributes:nil];
    
    isCachedToDisk = YES; // A valid file handle can be opened without downloading first
    isCachedInMemory = NO;
    
    itsAttributes = [[NSMutableDictionary alloc] initWithObjectsAndKeys: 
                     [NSNumber numberWithUnsignedLongLong:0], NSFileSize, 
                     [NSNumber numberWithInt:0700], NSFilePosixPermissions, 
                     [NSNumber numberWithInt:geteuid()], NSFileOwnerAccountID,
                     [NSNumber numberWithInt:getegid()], NSFileGroupOwnerAccountID,
                     [NSDate date], NSFileCreationDate,
                     [NSDate date], NSFileModificationDate,
                     NSFileTypeRegular, NSFileType,
                     nil];
    
    return self;
}

#pragma Caching
- (void) cacheToMemory
{
    // TODO check mtimes
    if ( !isCachedInMemory )
    {
        data = [[NSData alloc] initWithContentsOfFile:itsDiskPath];
        isCachedInMemory = YES;
    }
}

- (void) deleteFromMemory
{
    if (!isCachedInMemory)
        return;
    
    [data release];
    data = nil;
    isCachedInMemory = NO;
}

- (void) deleteFromDisk
{
    if (!isCachedToDisk)
        return;

    NSFileManager *filemgr;
    
    filemgr = [NSFileManager defaultManager];
    
    if ([filemgr removeItemAtPath:itsDiskPath error:nil]  == YES)
        self.isCachedToDisk = NO;
}

- (void) renameInCache:(NSString *)newname
{
    NSFileManager *filemgr;
    
    filemgr = [NSFileManager defaultManager];
    
    NSString *newpath = [itsCachePath stringByAppendingPathComponent:newname];
    NSError *error = nil;
    
    if ([filemgr moveItemAtPath:itsDiskPath toPath:newpath error:&error]  == YES)
        itsDiskPath = [newpath retain];
}

#pragma Downloading
- (void) download
{
    // download from the URL at clWebItem.remoteURL
    // and save it to path/clWebItem.name
    NSURLRequest *req = [NSURLRequest requestWithURL:[itsCLWebItem remoteURL] 
                                         cachePolicy:NSURLRequestUseProtocolCachePolicy 
                                     timeoutInterval:60.0];
    
    NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:req delegate:self];
        
    if (!conn)
    {
        NSLog(@"Failed to connect to remote URL! (%@)", [itsCLWebItem remoteURL]);
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    // This method is called when the server has determined that it
    // has enough information to create the NSURLResponse.
    
    // It can be called multiple times, for example in the case of a
    // redirect, so each time we reset the data.

    currentOffset = 0ULL;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)theData
{
    [self.fileHandle seekToFileOffset:currentOffset];
    [self.fileHandle writeData:theData];
    currentOffset += [theData length];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    // release the connection
    [connection release];
    
    // close the file
    [itsFileHandle closeFile];
    [itsFileHandle release];
    itsFileHandle = nil;
    
    // mark that this NimbusFile is cached
    self.isCachedToDisk = YES;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    // release the connection, and the data object
    [connection release];
    
    // inform the user
    NSLog(@"Connection failed! Error - %@ %@", [error localizedDescription], [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
}

- (void) dealloc
{
    [self deleteFromMemory];
    [self deleteFromDisk];
    
    [itsCLWebItem release];
    [itsDiskPath release];
    [itsAttributes release];
    
    [super dealloc];
}

@end
