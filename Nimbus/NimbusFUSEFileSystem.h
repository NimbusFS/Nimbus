//
//  NimbusFUSEFileSystem.h
//  Nimbus
//
//  Created by Sagar Pandya on 2/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Cloud.h"

@class GMUserFileSystem;

@interface NimbusFUSEFileSystem: NSObject <CLAPIEngineDelegate> 
{
    GMUserFileSystem* fs_;
    CLAPIEngine* engine_;
    
    NSMutableDictionary* cloudFiles;
    NSString* cachePath;
    
    BOOL isLoggedIn;
    BOOL hasMorePages;
    NSInteger whichPage;
}

// special constructor
- (NimbusFUSEFileSystem *) initWithUsername:(NSString *)username andPassword:(NSString *)password atMountPath:(NSString *)mountPath;
- (void) getNextPage;
- (BOOL) login;
- (void) unmount;

@property (retain, nonatomic) NSMutableDictionary* cloudFiles;
@property (retain, nonatomic) NSString* cachePath;
@property (retain, nonatomic) CLAPIEngine *engine_;
@property (nonatomic) NSInteger whichPage;
@property (assign, atomic) BOOL isLoggedIn;
@property (assign, atomic) BOOL hasMorePages;

@end
