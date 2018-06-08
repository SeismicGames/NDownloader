#import "NDownloader.h"
#import "DownloadData.h"

@implementation NDownloader

+ (id)sharedNDownloader {
    static NDownloader *_nDownloader = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _nDownloader = [[self alloc] init];
    });

    return _nDownloader;
}

- (id)init {
    self = [super init];
    if (self) {
        // init downloading session
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        NSString *bundleId = [bundle bundleIdentifier];
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration
            backgroundSessionConfigurationWithIdentifier:bundleId];
        configuration.discretionary = false;
        configuration.sessionSendsLaunchEvents = true;
        configuration.allowsCellularAccess = true;
        configuration.waitsForConnectivity = true;
        _session = [NSURLSession sessionWithConfiguration:configuration
                                                 delegate:self
                                            delegateQueue:nil];
    }

    return self;
}

- (NSUInteger)startDownload:(NSString *)url
                   tempFile:(NSString *)tempFile; {
    NSURL *URL = [NSURL URLWithString:url];

    NSURLSessionDownloadTask *downloadTask;
    downloadTask = [_session downloadTaskWithURL:URL];

    // handle temp file
    NSString *tempDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    DownloadData *data = [[DownloadData alloc] init];
    [data setId:[downloadTask taskIdentifier]];
    [data setLocation:[NSURL URLWithString:[NSString stringWithFormat:@"file://%@", [tempDir stringByAppendingPathComponent:tempFile]]]];
    [data setProgress:0];
    [data save];

    [downloadTask resume];

    NSLog(@"%@", [NSString stringWithFormat:@"Started download %@ from %@", @([downloadTask taskIdentifier]), url]);
    return [downloadTask taskIdentifier];
}

- (NSInteger)checkStatus:(NSUInteger)downloadId {
    DownloadData *data = [[DownloadData alloc] initWithId:downloadId];
    if (data == nil) {
        NSLog(@"%@", [NSString stringWithFormat:@"ID %@ passed in was not found", @(downloadId)]);
        return -1;
    }
    
    return [data progress];
}

- (NSString *)getError:(NSUInteger)downloadId {
    DownloadData *data = [[DownloadData alloc] initWithId:downloadId];
    if (data == nil) {
        NSString *errStr = [NSString stringWithFormat:@"id %@ passed in has no error", @(downloadId)];
        NSLog(@"%@", errStr);
        return errStr;
    }

    return [data error];
}

- (bool) moveFile:(NSUInteger)downloadId
      destination:(NSString *)destination {
    DownloadData *data = [[DownloadData alloc] initWithId:downloadId];
    if (data == nil) {
        NSLog(@"%@", [NSString stringWithFormat:@"id %@ passed in has no file to move", @(downloadId)]);
        return false;
    }
    
    NSURL *destUrl = [NSURL URLWithString:[NSString stringWithFormat:@"file://%@", destination]];
    NSLog(@"%@", [NSString stringWithFormat:@"Attempting to MoveFile from: %@ to: %@", [data location], destUrl]);
    NSError *error = nil;
    [[NSFileManager defaultManager] copyItemAtURL:[data location]
                                            toURL:destUrl
                                            error:&error];
    if (error != nil) {
        NSLog(@"%@", [NSString stringWithFormat:@"MoveFile failed: %@", error]);
        return false;
    }
    
    NSLog(@"%@", [NSString stringWithFormat:@"MoveFile from: %@ to: %@ succeeded", [data location], [destUrl path]]);
    return true;
}

- (void)removeFile:(NSUInteger)downloadId {
    DownloadData *data = [[DownloadData alloc] initWithId:downloadId];
    if (data == nil) {
        NSLog(@"%@", [NSString stringWithFormat:@"id %@ passed in has no file to remove", @(downloadId)]);
        return;
    }

    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtURL:[data location]
                                              error:&error];

    if (error != nil) {
        NSLog(@"%@", [NSString stringWithFormat:@"RemoveFile failed: %@", error]);
    }
    
    NSLog(@"%@", [NSString stringWithFormat:@"RemoveFile %@ succeeded", [data location]]);
    [data remove];
}

#pragma mark NSURLSessionDownloadDelegate
- (void)        URLSession:(NSURLSession *)session
              downloadTask:(NSURLSessionDownloadTask *)downloadTask
 didFinishDownloadingToURL:(NSURL *)location {
    NSLog(@"%@", [NSString stringWithFormat:@"File downloaded to: %@", location]);

    DownloadData *data = [[DownloadData alloc] initWithId:[downloadTask taskIdentifier]];
    if(data == nil) {
        NSLog(@"%@", [NSString stringWithFormat:@"id %lu cannot be found", (unsigned long)[downloadTask taskIdentifier]]);
        return;
    }
    
    // have to move the file in here or else it will disappear
    NSError *error = nil;
    [[NSFileManager defaultManager] copyItemAtURL:location
                                            toURL:[data location]
                                            error:&error];
    
    if (error == nil) {
        // finally set download progress to 100%
        [data setProgress:100];
    } else {
        NSLog(@"%@", [NSString stringWithFormat:@"Copying file after download failed: %@", error]);
        [data setProgress:-1];
    }
    
    [data save];
}

- (void)        URLSession:(NSURLSession *)session
              downloadTask:(NSURLSessionDownloadTask *)downloadTask
              didWriteData:(int64_t)bytesWritten
         totalBytesWritten:(int64_t)totalBytesWritten
 totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    // calculate download progress
    float percentageCompleted = ((float) totalBytesWritten / (float) totalBytesExpectedToWrite) * 100;
    int progress = (int) floor(percentageCompleted);
    
    // this code block should never set progress to 100, the completionHandler will do that
    // to confirm the download is 100% finished
    if(progress >= 100) {
        progress = 99;
    }
    
    // finally set download progress to 100%
    DownloadData *data = [[DownloadData alloc] initWithId:[downloadTask taskIdentifier]];
    if(data == nil) {
        NSLog(@"%@", [NSString stringWithFormat:@"id %lu cannot be found", (unsigned long)[downloadTask taskIdentifier]]);
        return;
    }
    
    [data setProgress:progress];
    [data save];
}

#pragma mark NSURLSessionTaskDelegate
- (void)   URLSession:(NSURLSession *)session
                 task:(NSURLSessionTask *)downloadTask
 didCompleteWithError:(nullable NSError *)error {
    if(error == nil) {
        // no error, but this still fires!
        return;
    }
    
    NSString *errStr = [NSString stringWithFormat:@"Download failed, error: %@", error];
    DownloadData *data = [[DownloadData alloc] initWithId:[downloadTask taskIdentifier]];
    if(data == nil) {
        NSLog(@"%@", [NSString stringWithFormat:@"id %lu cannot be found", (unsigned long)[downloadTask taskIdentifier]]);
        return;
    }
    
    [data setProgress:-1];
    [data setError:errStr];
    [data save];
}

#pragma mark NSURLSessionDelegate
- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session {
    NSLog(@"Resumed download from background");
    // TODO: what to do
}

@end
