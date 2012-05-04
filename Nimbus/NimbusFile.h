//
//  NimbusFile.h
//  Nimbus
//
//  Created by Sagar Pandya on 2/5/12.
//  Copyright (c) 2012. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Cloud.h"

@interface NimbusFile : NSObject <NSURLDownloadDelegate>
{
    CLWebItem *itsCLWebItem;
    NSString *itsDiskPath; // path to this file on disk
    NSString *itsCachePath; // path to the directory where this file will live on disk
    NSData* data;
    BOOL isCachedToDisk;
    BOOL isCachedInMemory;
    NSMutableDictionary *itsAttributes;

    NSFileHandle *itsFileHandle;
    unsigned long long currentOffset;
    unsigned long long totalFileLength;
}

@property (retain, nonatomic) CLWebItem *itsCLWebItem;
@property (retain, nonatomic) NSString *itsDiskPath;
@property (retain, nonatomic) NSString *itsCachePath;
@property (retain, nonatomic) NSData* data;
@property (retain, nonatomic) NSMutableDictionary* itsAttributes;
@property (atomic) BOOL isCachedToDisk;
@property (atomic) BOOL isCachedInMemory;

/**
 * Create a file locally for upload.
 */
- (NimbusFile *) initWithName:(NSString*)aName andCachePath:(NSString*)aPath;
- (NimbusFile *) initWithWebItem:(CLWebItem *)webItem andCachePath:(NSString *)path;

- (NSFileHandle*) fileHandle;
- (NSDictionary*) attributes;

- (void) download;
- (void) cacheToMemory;
- (void) renameInCache:(NSString *)newname;
- (void) deleteFromMemory;
- (void) deleteFromDisk;

@end
