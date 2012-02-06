//
//  NimbusFile.m
//  Nimbus
//
//  Created by Sagar Pandya on 2/5/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "NimbusFile.h"

@implementation NimbusFile

@synthesize itsCLWebItem;
@synthesize itsCachePath;
@synthesize isCachedToDisk;
@synthesize isCachedInMemory;
@synthesize data;

- (NimbusFile *) initWithWebItem:(CLWebItem *)webItem andCachePath:(NSString *)path
{
    self = [super init];
    if (!self) return nil;
    
    itsCLWebItem = [webItem retain];
    itsCachePath = [[NSString alloc] initWithFormat:@"%@/%@", path, [[webItem name] lastPathComponent]];
    isCachedToDisk = NO;
    isCachedInMemory = NO;
    return self;
}

- (void) cacheToMemory
{
    if ( !isCachedInMemory )
    {
        data = [[NSData alloc] initWithContentsOfFile:itsCachePath];
        isCachedInMemory = YES;
    }
}

- (void) deleteFromMemory
{
    [data release];
    [data dealloc];
    data = nil;
    isCachedInMemory = NO;
}

- (void) download
{
    // blah
    // download from the URL at clWebItem.remoteURL
    // and save it to path/clWebItem.name
    itsFileHandle = [NSFileHandle fileHandleForWritingAtPath:itsCachePath];
    if (itsFileHandle == nil)
    {
        [[NSFileManager defaultManager] createFileAtPath:itsCachePath contents:nil attributes:nil];
        itsFileHandle = [NSFileHandle fileHandleForWritingAtPath:itsCachePath];
        
        [itsFileHandle retain];
        currentOffset = 0ULL;
            
        NSURLRequest *req = [NSURLRequest requestWithURL:[itsCLWebItem remoteURL] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0];
        NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:req delegate:self];
        
        if (!conn)
        {
            NSLog(@"Failed to connect to remote URL! (%@)", [itsCLWebItem remoteURL]);
        }
    }
    else
    {
        isCachedToDisk = YES;
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
    [itsFileHandle seekToFileOffset:currentOffset];
    [itsFileHandle writeData:theData];
    currentOffset += [theData length];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    // do something with the data
    NSLog(@"Succeeded!");
    
    // release the connection
    [connection release];
    
    // close the file
    [itsFileHandle closeFile];
    
    // mark that this NimbusFile is cached
    isCachedToDisk = YES;
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
    
    [itsCLWebItem release];
    
    [itsCachePath release];
    itsCachePath = nil;
    
    [itsFileHandle closeFile];
    [itsFileHandle release];
    itsFileHandle = nil;
    
    [super dealloc];
}

@end
