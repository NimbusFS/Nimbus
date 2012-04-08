//
//  NSAttributedString+Hyperlink.h
//  NimbusPrefs
//
//  Created by Sagar Pandya on 3/21/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSAttributedString (Hyperlink)

+ (id)hyperlinkFromString:(NSString *)inString withURL:(NSURL *)aURL;

@end
