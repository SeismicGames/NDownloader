#import <Foundation/Foundation.h>

@interface UnityHelper : NSObject

@end

#if __cplusplus
extern "C" {
#endif
    extern unsigned long _startDownload(const char* url, const char* tempFile);
    
    extern long _checkStatus(unsigned long id);
    
    extern const char* _getError(unsigned long id);
    
    extern bool _moveFile(unsigned long id, const char* destination);
    
    extern void _removeFile(unsigned long id);
#if __cplusplus
}
#endif
