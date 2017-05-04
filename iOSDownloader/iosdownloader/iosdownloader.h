#import <Foundation/Foundation.h>
#import <AFNetworking/AFNetworking.h>

@interface iosdownloader : NSObject

+ (NSString *) startDownload:(NSString *)url;
+ (int) checkStatus:(NSString *)downloadId;
+ (NSString *) getError:(NSString *)downloadId;
+ (BOOL) moveFile:(NSString *)downloadId
      destination:(NSString *)destination;
+ (void) removeFile:(NSString *)downloadId;

@end
