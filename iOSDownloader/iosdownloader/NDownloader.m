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
                destination:(NSString *)destination {
    NSURL *URL = [NSURL URLWithString:url];

    NSURLSessionDownloadTask *downloadTask;
    downloadTask = [_session downloadTaskWithURL:URL];

    DownloadData *data = [DownloadData init];
    [self storeInPrefs:_progressKey
                    id:[downloadTask taskIdentifier]
                  with:@0];

    [downloadTask resume];

    NSLog(@"%@", [NSString stringWithFormat:@"Started download %@ from %@", @([downloadTask taskIdentifier]), url]);
    return [downloadTask taskIdentifier];
}

- (int)checkStatus:(NSUInteger)downloadId {
    NSNumber *progress = (NSNumber *) [self readFromPrefs:_progressKey
                                                       id:downloadId];
    if (progress == nil) {
        NSLog(@"%@", [NSString stringWithFormat:@"ID %@ passed in was not found", @(downloadId)]);
        return -1;
    }

    return [progress intValue];
}

- (NSString *)getError:(NSUInteger)downloadId {
    NSString *errStr = (NSString *) [self readFromPrefs:_errorKey
                                                     id:downloadId];
    if (errStr == nil) {
        errStr = [NSString stringWithFormat:@"id %@ passed in has no error", @(downloadId)];
        NSLog(@"%@", errStr);
        return errStr;
    }

    return errStr;
}

- (void)removeFile:(NSUInteger)downloadId {
    NSURL *path = (NSURL *) [self readFromPrefs:_locationKey
                                             id:downloadId];
    if (path == nil) {
        NSLog(@"%@", [NSString stringWithFormat:@"id %@ passed in has no file to remove", @(downloadId)]);
        return;
    }

    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:path
                                               error:&error];

    if (error != nil) {
        NSLog(@"%@", [NSString stringWithFormat:@"RemoveFile failed: %@", error]);
    }
}

// safer to have Unity clean up then try to guess
- (void)cleanup:(NSUInteger)downloadId {
    [self deleteFromPrefs:_progressKey id:downloadId];
    [self deleteFromPrefs:_locationKey id:downloadId];
    [self deleteFromPrefs:_errorKey id:downloadId];
}

#pragma mark NSURLSessionDownloadDelegate
- (void)        URLSession:(NSURLSession *)session
              downloadTask:(NSURLSessionDownloadTask *)downloadTask
 didFinishDownloadingToURL:(NSURL *)location {
    NSLog(@"%@", [NSString stringWithFormat:@"File downloaded to: %@", location]);

    // mark the location of the download so we can move it
    [self storeInPrefs:_locationKey
                    id:[downloadTask taskIdentifier]
                  with:location];

    // finally set download progress to 100%
    [self storeInPrefs:_progressKey
                    id:[downloadTask taskIdentifier]
                  with:@100];
}

- (void)        URLSession:(NSURLSession *)session
              downloadTask:(NSURLSessionDownloadTask *)downloadTask
              didWriteData:(int64_t)bytesWritten
         totalBytesWritten:(int64_t)totalBytesWritten
 totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    // calculate download progress
    float percentageCompleted = (float) totalBytesWritten / (float) totalBytesExpectedToWrite;
    int progress = (int) floor(percentageCompleted);

    // this code block should never set progress to 100, the completionHandler will do that
    // to confirm the download is 100% finished
    if(progress >= 100) {
        progress = 99;
    }

    // finally set download progress to 100%
    [self storeInPrefs:_progressKey
                    id:[downloadTask taskIdentifier]
                  with:@(progress)];
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
    NSLog(@"%@", errStr);
    [self storeInPrefs:_errorKey
                    id:[downloadTask taskIdentifier]
                  with:errStr];
    [self storeInPrefs:_progressKey
                    id:[downloadTask taskIdentifier]
                  with:@(-1)];
}

#pragma mark NSURLSessionDelegate
- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session {
    NSLog(@"Resumed download from background");
    // TODO: what to do
}

@end
