//
// Created by Keith Miller on 2/5/18.
// Copyright (c) 2018 Keith Miller. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DownloadData : NSObject <NSCoding>

@property (readwrite) NSUInteger id;
@property (readonly) NSString *downloadMapKey;
@property (readwrite) NSURL *location;
@property (readwrite) NSInteger progress;
@property (readwrite) NSString *error;

- (instancetype)init;
- (instancetype)initWithId:(NSUInteger)downloadId;
- (void)save;
- (void)remove;

@end
