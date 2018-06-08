#import <Foundation/Foundation.h>

@interface NDownloader : NSObject <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDownloadDelegate> {
    NSURLSession *_session;
}

// singleton method
+ (id)sharedNDownloader;

// class methods
- (NSUInteger) startDownload:(NSString *)url
                    tempFile:(NSString *)tempFile;
- (NSInteger) checkStatus:(NSUInteger)downloadId;
- (NSString *) getError:(NSUInteger)downloadId;
- (bool) moveFile:(NSUInteger)downloadId
      destination:(NSString *)destination;
- (void) removeFile:(NSUInteger)downloadId;

@end
