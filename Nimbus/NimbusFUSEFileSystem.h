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
}

// special constructor
- (NimbusFUSEFileSystem *) initWithUsername:(NSString *)username andPassword:(NSString *)password atMountPath:(NSString *)mountPath;
- (void) getNextPage;

@property (retain, nonatomic) NSMutableDictionary* cloudFiles;
@property (retain, nonatomic) NSString* cachePath;

@end
