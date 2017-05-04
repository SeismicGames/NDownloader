#import <Foundation/Foundation.h>

@interface UnityHelper : NSObject

@end

#if __cplusplus
extern "C" {
#endif
    extern const char* _startDownload(const char* url);
    
    extern int _checkStatus(const char* Id);
    
    extern const char* _getError(const char* Id);
    
    extern bool _moveFile(const char* Id, const char* destination);
    
    extern void _removeFile(const char* Id);
#if __cplusplus
}
#endif
