#import "iosdownloader.h"

@implementation iosdownloader
static NSMutableDictionary *downloadMap;
static NSMutableDictionary *downloadProgessMap;
static NSMutableDictionary *downloadErrorMap;
static NSMutableDictionary *downloadLocationMap;

+ (NSString *)startDownload:(NSString *)url {
    if (downloadMap == nil) {
        downloadMap = [[NSMutableDictionary alloc] init];
    }
    
    if (downloadProgessMap == nil) {
        downloadProgessMap = [[NSMutableDictionary alloc] init];
    }
    
    if (downloadErrorMap == nil) {
        downloadErrorMap = [[NSMutableDictionary alloc] init];
    }
    
    if (downloadLocationMap == nil) {
        downloadLocationMap = [[NSMutableDictionary alloc] init];
    }
    
    NSUUID *uuid = [[NSUUID alloc] init];
    
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];
    
    NSURL *URL = [NSURL URLWithString:url];
    NSURLRequest *request = [NSURLRequest requestWithURL:URL];
    
    [manager setDownloadTaskDidWriteDataBlock:^(NSURLSession * _Nonnull session, NSURLSessionDownloadTask * _Nonnull downloadTask, int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        
        CGFloat written = totalBytesWritten;
        CGFloat total = totalBytesExpectedToWrite;
        CGFloat percentageCompleted = written/total;
        int progress = (int) (percentageCompleted * 100);
        
        // this code block should never set progress to 100, the completionHandler will do that
        // to confirm the download is 100% finished
        if(progress >= 100) {
            progress = 99;
        }
        
        [downloadProgessMap setObject:[NSNumber numberWithInt:progress]
                               forKey:[uuid UUIDString]];
    }];
    
    NSURLSessionDownloadTask *downloadTask = [manager downloadTaskWithRequest:request
                                                                     progress:nil
                                                                  destination:^NSURL *(NSURL *targetPath, NSURLResponse *response) {
        NSURL *documentsDirectoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory
                                                                              inDomain:NSUserDomainMask
                                                                     appropriateForURL:nil
                                                                                create:NO
                                                                                 error:nil];
        return [documentsDirectoryURL URLByAppendingPathComponent:[response suggestedFilename]];
    } completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
        // TODO: check error
        if(error != nil) {
            NSString *errStr = [NSString stringWithFormat:@"Download failed, error: %@", error];
            NSLog(@"%@", errStr);
            [downloadErrorMap setObject:errStr
                                 forKey:[uuid UUIDString]];
            return;
        }
        
        // add where file was placed so we can move it if we want to
        [downloadLocationMap setObject:filePath
                                forKey:[uuid UUIDString]];
        
        NSLog(@"%@", [NSString stringWithFormat:@"File downloaded to: %@", filePath]);
        
        // finally set download progress to 100%
        [downloadProgessMap setObject:[NSNumber numberWithInt:100]
                               forKey:[uuid UUIDString]];
    }];
    
    [downloadMap setObject:downloadTask
                    forKey:[uuid UUIDString]];
    [downloadProgessMap setObject:[NSNumber numberWithFloat:0.0f]
                           forKey:[uuid UUIDString]];
    
    [downloadTask resume];
    
    NSLog(@"%@", [NSString stringWithFormat:@"Started download from %@", url]);
    return [uuid UUIDString];
}

+ (int)checkStatus:(NSString *)downloadId
{
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:[downloadId uppercaseString]];
    if(uuid == nil) {
        NSLog(@"%@", @"Invalid UUID passed to checkStatus");
        return -1;
    }
    
    NSNumber *progress = [downloadProgessMap objectForKey:[uuid UUIDString]];
    if(progress == nil) {
        NSLog(@"%@", [NSString stringWithFormat:@"UUID %@ passed in was not found", uuid]);
        return -1;
    }
    
    if([progress intValue] == 100) {
        // clean up download hashmaps
        [downloadMap removeObjectForKey:[uuid UUIDString]];
        [downloadProgessMap removeObjectForKey:[uuid UUIDString]];
    }
    
    return [progress intValue];
}

+ (NSString *) getError:(NSString *)downloadId
{
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:[downloadId uppercaseString]];
    if(uuid == nil) {
        NSLog(@"%@", @"Invalid UUID passed to checkStatus");
        return @"Invalid UUID passed to getError";
    }
    
    NSString *errStr = [downloadErrorMap objectForKey:[uuid UUIDString]];
    if(errStr == nil) {
        errStr = [NSString stringWithFormat:@"UUID %@ passed in has no error", uuid];
        NSLog(@"%@", errStr);
        return errStr;
    }

    return errStr;
}

+ (BOOL) moveFile:(NSString *)downloadId
      destination:(NSString *)destination
{
    if([destination length] == 0 || [NSURL URLWithString:destination] == nil) {
        NSLog(@"%@", [NSString stringWithFormat:@"MoveFile invalid destination %@ passsed in", destination]);
        return false;
    }
    
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:[downloadId uppercaseString]];
    if(uuid == nil) {
        NSLog(@"%@", @"Invalid UUID passed to removeFile");
        return false;
    }
    
    NSURL *path = [downloadLocationMap objectForKey:[uuid UUIDString]];
    if(path == nil) {
        NSLog(@"%@", [NSString stringWithFormat:@"UUID %@ passed in has no mapped location", uuid]);
        return false;
    }
    
    NSURL *destPath = nil;
    if([destination hasPrefix:@"file://"]) {
        destPath = [NSURL URLWithString:destination];
    } else {
        destPath = [NSURL URLWithString:[NSString stringWithFormat:@"file://%@", destination]];
    }
    
    if([[path absoluteString] isEqualToString:[destPath absoluteString]]) {
        [downloadLocationMap removeObjectForKey:[uuid UUIDString]];
        return true;
    }
    
    NSError *error = nil;
    [[NSFileManager defaultManager] moveItemAtURL:path
                                            toURL:destPath
                                            error:&error];
    
    if (error == nil) {
        [downloadLocationMap removeObjectForKey:[uuid UUIDString]];
        return true;
    } else {
        NSLog(@"%@", [NSString stringWithFormat:@"MoveFile failed: %@", error]);
        return false;
    }
}

+ (void) removeFile:(NSString *)downloadId
{
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:[downloadId uppercaseString]];
    if(uuid == nil) {
        NSLog(@"%@", @"Invalid UUID passed to removeFile");
        return;
    }
    
    NSString *path = [downloadLocationMap objectForKey:[uuid UUIDString]];
    if(path == nil) {
        NSLog(@"%@", [NSString stringWithFormat:@"UUID %@ passed in has no file to remove", uuid]);
        return;
    }
    
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:path
                                               error:&error];
    
    if(error != nil) {
        NSLog(@"%@", [NSString stringWithFormat:@"RemoveFile failed: %@", error]);
    }
    
    [downloadLocationMap removeObjectForKey:[uuid UUIDString]];
}

@end
