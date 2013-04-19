//
//  NSString+na.m
//  SK3
//
//  Created by nashibao on 2013/01/21.
//  Copyright (c) 2013年 s-cubism. All rights reserved.
//

#import "NSString+na.h"

@implementation NSString (na)

- (NSString *)encodeURIComponentByEncoding:(NSStringEncoding)encoding{
    return (__bridge_transfer NSString *)CFURLCreateStringByAddingPercentEscapes(NULL,
                                                                                 (__bridge CFStringRef)self,
                                                                                 NULL,
                                                                                 (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ",
                                                                                 CFStringConvertNSStringEncodingToEncoding(encoding));
}

@end