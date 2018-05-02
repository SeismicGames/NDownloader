//
// Created by Keith Miller on 2/5/18.
// Copyright (c) 2018 Keith Miller. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DownloadData : NSObject <NSCoding> {
    // for NSUserDefaults
    NSString *_downloadMapKey;
}

@property (readonly) NSUInteger id;
@property (readwrite) NSURL *location;
@property (readwrite) NSURL *destination;
@property (readwrite) float progress;
@property (readwrite) NSString *error;

- (instancetype)initWithId:(NSUInteger)downloadId;
- (void)save;
- (void)delete;

@end