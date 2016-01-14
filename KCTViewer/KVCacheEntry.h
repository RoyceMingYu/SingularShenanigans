//
//  KVCacheEntry.h
//  KCTViewer
//
//  Created by Royce Yu on October 2nd, 2015
//  Copyright (c) 2015 the KanColleTool team. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface KVCacheEntry : NSObject <NSCoding>

@property (nonatomic, strong) NSURLRequest *request;
@property (nonatomic, strong) NSURLResponse *response;
@property (nonatomic, strong) NSMutableData *data;

- (id)initWithRequest:(NSURLRequest *)request;
- (id)initWithCoder:(NSCoder *)aDecoder;
- (void)encodeWithCoder:(NSCoder *)aCoder;

- (void)appendData:(NSData *)data;

@end
