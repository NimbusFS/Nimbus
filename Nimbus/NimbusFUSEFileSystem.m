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

#pragma mark- Overridden GMUserFileSystem delegate methods-
/*! 
 * @category
 * @discussion The core set of file system operations the delegate must implement.
 * Unless otherwise noted, they typically should behave like the NSFileManager 
 * equivalent. However, the error codes that they return should correspond to
 * the BSD-equivalent call and be in the NSPOSIXErrorDomain.<br>
 *
 * For a read-only filesystem, you can typically pick-and-choose which methods
 * to implement.  For example, a minimal read-only filesystem might implement:<ul>
 *   - (NSArray *)contentsOfDirectoryAtPath:(NSString *)path 
 *                                    error:(NSError **)error;<br>
 *   - (NSDictionary *)attributesOfItemAtPath:(NSString *)path
 *                                   userData:(id)userData
 *                                      error:(NSError **)error;<br>
 *   - (NSData *)contentsAtPath:(NSString *)path;</ul>
 * For a writeable filesystem, the Finder can be quite picky unless the majority
 * of these methods are implemented. However, you can safely skip hard-links, 
 * symbolic links, and extended attributes.
 */
#pragma mark Directory Contents

/*!
 * @abstract Returns directory contents at the specified path.
 * @discussion Returns an array of NSString containing the names of files and
 * sub-directories in the specified directory.
 * @seealso man readdir(3)
 * @param path The path to a directory.
 * @param error Should be filled with a POSIX error in case of failure.
 * @result An array of NSString or nil on error.
 */
- (NSArray *)contentsOfDirectoryAtPath:(NSString *)path error:(NSError **)error 
{
    @synchronized(self)
    {
        return [cloudFiles allKeys];
    }
}

#pragma mark Getting and Setting Attributes

/*!
 * @abstract Returns attributes at the specified path.
 * @discussion
 * Returns a dictionary of attributes at the given path. It is required to 
 * return at least the NSFileType attribute. You may omit the NSFileSize
 * attribute if contentsAtPath: is implemented, although this is less efficient.
 * The following keys are currently supported (unknown keys are ignored):<ul>
 *   <li>NSFileType [Required]
 *   <li>NSFileSize [Recommended]
 *   <li>NSFileModificationDate
 *   <li>NSFileReferenceCount
 *   <li>NSFilePosixPermissions
 *   <li>NSFileOwnerAccountID
 *   <li>NSFileGroupOwnerAccountID
 *   <li>NSFileSystemFileNumber             (64-bit on 10.5+)
 *   <li>NSFileCreationDate                 (if supports extended dates)
 *   <li>kGMUserFileSystemFileBackupDateKey (if supports extended dates)
 *   <li>kGMUserFileSystemFileChangeDateKey
 *   <li>kGMUserFileSystemFileAccessDateKey
 *   <li>kGMUserFileSystemFileFlagsKey
 *   <li>kGMUserFileSystemFileSizeInBlocksKey</ul>
 *
 * If this is the fstat variant and userData was supplied in openFileAtPath: or 
 * createFileAtPath: then it will be passed back in this call.
 *
 * @seealso man stat(2), fstat(2)
 * @param path The path to the item.
 * @param userData The userData corresponding to this open file or nil.
 * @param error Should be filled with a POSIX error in case of failure.
 * @result A dictionary of attributes or nil on error.
 */
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
        if ([path isEqualToString:@"/"])
        {
            NSMutableDictionary *attr = [NSDictionary dictionaryWithObjectsAndKeys:
                                         [NSNumber numberWithInt:0700], NSFilePosixPermissions,
                                         [NSNumber numberWithInt:geteuid()], NSFileOwnerAccountID,
                                         [NSNumber numberWithInt:getegid()], NSFileGroupOwnerAccountID,
                                         [NSDate date], NSFileCreationDate,
                                         [NSDate date], NSFileModificationDate,
                                         NSFileTypeDirectory, NSFileType,
                                         nil];
            return attr;
        } else {
            NimbusFile *file = [cloudFiles objectForKey:[path lastPathComponent]];
            
            if (file == nil)
                return nil;
            
            return [file attributes];
        }
    }
}

/*!
 * @abstract Returns file system attributes.
 * @discussion
 * Returns a dictionary of attributes for the file system.
 * The following keys are currently supported (unknown keys are ignored):<ul>
 *   <li>NSFileSystemSize
 *   <li>NSFileSystemFreeSize
 *   <li>NSFileSystemNodes
 *   <li>NSFileSystemFreeNodes
 *   <li>kGMUserFileSystemVolumeSupportsExtendedDatesKey
 *   <li>kGMUserFileSystemVolumeMaxFilenameLengthKey
 *   <li>kGMUserFileSystemVolumeFileSystemBlockSizeKey</ul>
 *
 * @seealso man statvfs(3)
 * @param path A path on the file system (it is safe to ignore this).
 * @param error Should be filled with a POSIX error in case of failure.
 * @result A dictionary of attributes for the file system.
 */

/*- (NSDictionary *)attributesOfFileSystemForPath:(NSString *)path
                                          error:(NSError **)error
{
    NSLog(@"Attributes of FS for path");
}*/

/*!
 * @abstract Set attributes at the specified path.
 * @discussion
 * Sets the attributes for the item at the specified path. The following keys
 * may be present (you must ignore unknown keys):<ul>
 *   <li>NSFileSize
 *   <li>NSFileOwnerAccountID
 *   <li>NSFileGroupOwnerAccountID
 *   <li>NSFilePosixPermissions
 *   <li>NSFileModificationDate
 *   <li>NSFileCreationDate                  (if supports extended dates)
 *   <li>kGMUserFileSystemFileBackupDateKey  (if supports extended dates)
 *   <li>kGMUserFileSystemFileChangeDateKey
 *   <li>kGMUserFileSystemFileAccessDateKey
 *   <li>kGMUserFileSystemFileFlagsKey</ul>
 *
 * If this is the f-variant and userData was supplied in openFileAtPath: or 
 * createFileAtPath: then it will be passed back in this call.
 *
 * @seealso man truncate(2), chown(2), chmod(2), utimes(2), chflags(2),
 *              ftruncate(2), fchown(2), fchmod(2), futimes(2), fchflags(2)
 * @param attributes The attributes to set.
 * @param path The path to the item.
 * @param userData The userData corresponding to this open file or nil.
 * @param error Should be filled with a POSIX error in case of failure.
 * @result YES if the attributes are successfully set.
 */
- (BOOL)setAttributes:(NSDictionary *)attributes 
         ofItemAtPath:(NSString *)path
             userData:(id)userData
                error:(NSError **)error
{
    @synchronized(self) {
        NimbusFile *file = [cloudFiles objectForKey:[path lastPathComponent]];
        if (file == nil) {
            NSLog(@"File not found!");
            *error = [NSError errorWithPOSIXCode:ENOENT];
            return NO;
        }
        
        if ([file isCachedToDisk]) {
            [[NSFileManager defaultManager] setAttributes:attributes ofItemAtPath:[file itsDiskPath] error:error];
        } else {
            NSLog(@"File wasn't cached!");
            return NO;
        }
        
        return YES;
    }
}

#pragma mark File Contents

/*!
 * @abstract Returns file contents at the specified path.
 * @discussion Returns the full contents at the given path. Implementation of
 * this delegate method is recommended only by very simple file systems that are 
 * not concerned with performance. If contentsAtPath is implemented then you can 
 * skip open/release/read.
 * @param path The path to the file.
 * @result The contents of the file or nil if a file does not exist at path.
 */
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

/*!
 * @abstract Opens the file at the given path for read/write.
 * @discussion This will only be called for existing files. If the file needs
 * to be created then createFileAtPath: will be called instead.
 * @seealso man open(2)
 * @param path The path to the file.
 * @param mode The open mode for the file (e.g. O_RDWR, etc.)
 * @param userData Out parameter that can be filled in with arbitrary user data.
 *        The given userData will be retained and passed back in to delegate
 *        methods that are acting on this open file.
 * @param error Should be filled with a POSIX error in case of failure.
 * @result YES if the file was opened successfully.
 */
- (BOOL)openFileAtPath:(NSString *)path 
                  mode:(int)mode
              userData:(id *)userData
                 error:(NSError **)error
{
    NSLog(@"Openfileatpath %@", path);
}

/*!
 * @abstract Called when an opened file is closed.
 * @discussion If userData was provided in the corresponding openFileAtPath: call
 * then it will be passed in userData and released after this call completes.
 * @seealso man close(2)
 * @param path The path to the file.
 * @param userData The userData corresponding to this open file or nil.
 */
- (void)releaseFileAtPath:(NSString *)path userData:(id)userData
{
    NSLog(@"releasefileatpath %@", path);
}

/*!
 * @abstract Reads data from the open file at the specified path.
 * @discussion Reads data from the file starting at offset into the provided
 * buffer and returns the number of bytes read. If userData was provided in the 
 * corresponding openFileAtPath: or createFileAtPath: call then it will be
 * passed in.
 * @seealso man pread(2)
 * @param path The path to the file.
 * @param userData The userData corresponding to this open file or nil.
 * @param buffer Byte buffer to read data from the file into.
 * @param size The size of the provided buffer.
 * @param offset The offset in the file from which to read data.
 * @param error Should be filled with a POSIX error in case of failure.
 * @result The number of bytes read or -1 on error.
 */
- (int)readFileAtPath:(NSString *)path 
             userData:(id)userData
               buffer:(char *)buffer 
                 size:(size_t)size 
               offset:(off_t)offset
                error:(NSError **)error
{
    NSLog(@"Write at path %@", path);
    return -1;
}

/*!
 * @abstract Writes data to the open file at the specified path.
 * @discussion Writes data to the file starting at offset from the provided
 * buffer and returns the number of bytes written. If userData was provided in
 * the corresponding openFileAtPath: or createFileAtPath: call then it will be
 * passed in.
 * @seealso man pwrite(2)
 * @param path The path to the file.
 * @param userData The userData corresponding to this open file or nil.
 * @param buffer Byte buffer containing the data to write to the file.
 * @param size The size of the provided buffer.
 * @param offset The offset in the file to write data.
 * @param error Should be filled with a POSIX error in case of failure.
 * @result The number of bytes written or -1 on error.
 */
- (int)writeFileAtPath:(NSString *)path 
              userData:(id)userData
                buffer:(const char *)buffer
                  size:(size_t)size 
                offset:(off_t)offset
                 error:(NSError **)error
{
    // Find the nimbus file
    NimbusFile *nf = [cloudFiles objectForKey:[path lastPathComponent]];
    if (nf == nil) {
        *error = [NSError errorWithPOSIXCode:ENOENT];
        return -1;
    }
    // Get da handle and seek to the offset
    NSFileHandle *file = nf.fileHandle;
    [file seekToFileOffset:offset];
    
    // Write data
    NSData *data = [[NSData alloc] initWithBytes:buffer length:size];
    [file writeData:data];
    [data release];
    
    return size;
}

/*!
 * @abstract Atomically exchanges data between files.
 * @discussion  Called to atomically exchange file data between path1 and path2.
 * @seealso man exchangedata(2)
 * @param path1 The path to the file.
 * @param path2 The path to the other file.
 * @param error Should be filled with a POSIX error in case of failure.
 * @result YES if data was exchanged successfully.
 */
- (BOOL)exchangeDataOfItemAtPath:(NSString *)path1
                  withItemAtPath:(NSString *)path2
                           error:(NSError **)error
{
    NSLog(@"ExchangeDataofitematpathwithitematpath");
}

#pragma mark Creating an Item

/*!
 * @abstract Creates a directory at the specified path.
 * @discussion  The attributes may contain keys similar to setAttributes:.
 * @seealso man mkdir(2)
 * @param path The directory path to create.
 * @param attributes Set of attributes to apply to the newly created directory.
 * @param error Should be filled with a POSIX error in case of failure.
 * @result YES if the directory was successfully created.
 */
- (BOOL)createDirectoryAtPath:(NSString *)path 
                   attributes:(NSDictionary *)attributes
                        error:(NSError **)error
{
    NSLog(@"Create Directory at Path %@", path);
    return NO;
}

/*!
 * @abstract Creates and opens a file at the specified path.
 * @discussion  This should create and open the file at the same time. The 
 * attributes may contain keys similar to setAttributes:.
 * @seealso man creat(2)
 * @param path The path of the file to create.
 * @param attributes Set of attributes to apply to the newly created file.
 * @param userData Out parameter that can be filled in with arbitrary user data.
 *        The given userData will be retained and passed back in to delegate
 *        methods that are acting on this open file.
 * @param error Should be filled with a POSIX error in case of failure.
 * @result YES if the directory was successfully created.
 */
- (BOOL)createFileAtPath:(NSString *)path 
              attributes:(NSDictionary *)attributes
                userData:(id *)userData 
                   error:(NSError **)error
{    
    if ([path isEqualToString:@"/.DS_Store"]) {
        return NO;
    }
    NSLog(@"Adding file %@", path);
    
    if ([cloudFiles objectForKey:[path lastPathComponent]]) {
        // File exists!
        *error = [[NSError alloc] initWithDomain:NSPOSIXErrorDomain 
                                            code:EEXIST 
                                        userInfo:nil];
        return NO;
    }
    
    NimbusFile *nf = [[NimbusFile alloc] initWithName:[path lastPathComponent] 
                                         andCachePath:cachePath];    
    [cloudFiles setObject:nf forKey:[nf.itsCLWebItem name]];
    
    NSLog(@"%@", @"File created");
    return YES;
}

#pragma mark Moving an Item

/*!
 * @abstract Moves or renames an item.
 * @discussion Move, also known as rename, is one of the more difficult file
 * system methods to implement properly. Care should be taken to handle all 
 * error conditions and return proper POSIX error codes.
 * @seealso man rename(2)
 * @param source The source file or directory.
 * @param destination The destination file or directory.
 * @param error Should be filled with a POSIX error in case of failure.
 * @result YES if the move was successful.
 */
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


#pragma mark Removing an Item

/*!
 * @abstract Remove the directory at the given path.
 * @discussion Unlike NSFileManager, this should not recursively remove
 * subdirectories. If this method is not implemented, then removeItemAtPath 
 * will be called even for directories.
 * @seealso man rmdir(2)
 * @param path The directory to remove.
 * @param error Should be filled with a POSIX error in case of failure.
 * @result YES if the directory was successfully removed.
 */
- (BOOL)removeDirectoryAtPath:(NSString *)path error:(NSError **)error
{
    NSLog(@"Removedirectoratpath");
}

/*!
 * @abstract Removes the item at the given path.
 * @discussion This should not recursively remove subdirectories. If 
 * removeDirectoryAtPath is implemented, then that will be called instead of
 * this selector if the item is a directory.
 * @seealso man unlink(2), rmdir(2)
 * @param path The path to the item to remove.
 * @param error Should be filled with a POSIX error in case of failure.
 * @result YES if the item was successfully removed.
 */
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



#pragma mark- CLAPI callbacks
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
                if (![theFile isCachedToDisk]) {
                    [theFile download];
                }
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
