#import "UnityHelper.h"
#import "NDownloader.h"

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
    unsigned long _startDownload(const char* url, const char* tempFile) {
        NDownloader *nDownloader = [NDownloader sharedNDownloader];
        return [nDownloader startDownload:CreateNSString(url)
                                 tempFile:CreateNSString(tempFile)];
    }
    
    long _checkStatus(unsigned long id) {
        NDownloader *nDownloader = [NDownloader sharedNDownloader];
        return [nDownloader checkStatus:id];
    }
    
    const char* _getError(unsigned long id) {
        NDownloader *nDownloader = [NDownloader sharedNDownloader];
        NSString *errStr = [nDownloader getError:id];
        return MakeStringCopy(CreateConstChar(errStr));
    }

    bool _moveFile(unsigned long id, const char* destination) {
        NDownloader *nDownloader = [NDownloader sharedNDownloader];
        return [nDownloader moveFile:id
                         destination:CreateNSString(destination)];
    }
    
    void _removeFile(unsigned long id) {
        NDownloader *nDownloader = [NDownloader sharedNDownloader];
        [nDownloader removeFile:id];
    }
#if __cplusplus
}
#endif
