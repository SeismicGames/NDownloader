//
// Created by Keith Miller on 2/5/18.
// Copyright (c) 2018 Keith Miller. All rights reserved.
//

#import "DownloadData.h"

@implementation DownloadData

@synthesize id = _id;
@synthesize downloadMapKey = _downloadMapKey;
@synthesize location;
@synthesize progress;
@synthesize error;

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:@(_id) forKey:@"id"];
    [coder encodeObject:location forKey:@"location"];
    [coder encodeObject:@(progress) forKey:@"progress"];
    [coder encodeObject:error forKey:@"error"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if(self) {
        _id = [[coder decodeObjectForKey:@"id"] unsignedIntegerValue];
        location = [coder decodeObjectForKey:@"location"];
        progress = [[coder decodeObjectForKey:@"progress"] integerValue];
        error = [coder decodeObjectForKey:@"error"];

        _downloadMapKey = [NSString stringWithFormat:@"ndownloader_%@", [[NSBundle bundleForClass:[self class]] bundleIdentifier]];
    }

    return self;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _downloadMapKey = [NSString stringWithFormat:@"ndownloader_%@", [[NSBundle bundleForClass:[self class]] bundleIdentifier]];    }

    return self;
}

- (instancetype)initWithId:(NSUInteger)downloadId {
    self = [super init];
    if (self) {
        _downloadMapKey = [NSString stringWithFormat:@"ndownloader_%@", [[NSBundle bundleForClass:[self class]] bundleIdentifier]];
        
        NSString *key = [NSString stringWithFormat:@"%@_%lu", _downloadMapKey, downloadId];
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSData *data = [userDefaults objectForKey:key];
        if(data == nil) {
            return nil;
        }
        
        self = [NSKeyedUnarchiver unarchiveObjectWithData: data];
    }

    return self;
}

- (void)save {
    NSString *key = [NSString stringWithFormat:@"%@_%lu", _downloadMapKey, _id];
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:[NSKeyedArchiver archivedDataWithRootObject:self] forKey:key];
    [userDefaults synchronize];
}

- (void)remove {
    NSString *key = [NSString stringWithFormat:@"%@_%lu", _downloadMapKey, _id];
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults removeObjectForKey:key];
}

@end
