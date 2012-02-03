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
    CLAPIEngine *engine_;
    
    NSMutableDictionary* cloudFiles;
    BOOL hasMorePages;
    BOOL isDoneDownloading;
    NSInteger lastPageRetrieved;
}

// special constructor
- (NimbusFUSEFileSystem *) initWithUsername:(NSString *)username andPassword:(NSString *)password atMountPath:(NSString *)mountPath;

@property (retain, nonatomic) NSMutableDictionary* cloudFiles;

@end
