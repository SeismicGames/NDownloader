#import <Foundation/Foundation.h>

@interface UnityHelper : NSObject

@end

#if __cplusplus
extern "C" {
#endif
    extern unsigned long _startDownload(const char* url, const char* destination);
    
    extern int _checkStatus(unsigned long id);
    
    extern const char* _getError(unsigned long id);

    extern void cleanup(unsigned long id);
#if __cplusplus
}
#endif
