#import <Foundation/Foundation.h>

@interface NDownloader : NSObject <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDownloadDelegate> {
    NSURLSession *_session;
    NSString *_downloadMapKey;
}

// singleton method
+ (id)sharedNDownloader;

// class methods
- (NSUInteger) startDownload:(NSString *)url
                 destination:(NSString *)destination;
- (int) checkStatus:(NSUInteger)downloadId;
- (NSString *) getError:(NSUInteger)downloadId;
- (void) cleanup:(NSUInteger)downloadId;

@end
