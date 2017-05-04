#import "UnityHelper.h"
#import "iosdownloader.h"

@implementation UnityHelper

@end

// Converts C style string to NSString
NSString* CreateNSString(const char* string) {
    if (string) {
        return [NSString stringWithUTF8String:string];
    } else {
        return [NSString stringWithUTF8String:""];
    }
}

// Converts NSString to C style string
const char* CreateConstChar(NSString *string) {
    if(string == nil) {
        return "";
    } else {
        return [string UTF8String];
    }
}

// Helper method to create C string copy
char* MakeStringCopy (const char* string)
{
    if (string == NULL) {
        return NULL;
    }
    
    char* res = (char*)malloc(strlen(string) + 1);
    strcpy(res, string);
    return res;
}

#if __cplusplus
extern "C" {
#endif
    const char* _startDownload(const char* url) {
        NSString *uuid = [iosdownloader startDownload:CreateNSString(url)];
        return MakeStringCopy(CreateConstChar(uuid));
    }
    
    int _checkStatus(const char* Id) {
        return [iosdownloader checkStatus:CreateNSString(Id)];
    }
    
    const char* _getError(const char* Id) {
        NSString *errStr = [iosdownloader getError:CreateNSString(Id)];
        return MakeStringCopy(CreateConstChar(errStr));
    }
    
    bool _moveFile(const char* Id, const char* destination) {
        return [iosdownloader moveFile:CreateNSString(Id)
                           destination:CreateNSString(destination)];
    }
    
    void _removeFile(const char* Id) {
        [iosdownloader removeFile:CreateNSString(Id)];
    }
#if __cplusplus
}
#endif
