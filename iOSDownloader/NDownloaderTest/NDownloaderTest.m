//
//  NDownloaderTest.m
//  NDownloaderTest
//
//  Created by Keith Miller on 2/2/18.
//  Copyright © 2018 Keith Miller. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NDownloader.h"

@interface NDownloaderTest : XCTestCase

@end

@implementation NDownloaderTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.continueAfterFailure = false;
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
    
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:@"com.seismicgames.NDownloaderTest"];
}

- (void)testSuccessfulDownload {
    NSString *testUrl = @"http://ipv4.download.thinkbroadband.com/20MB.zip";
    NDownloader *nDownloader = [NDownloader sharedNDownloader];
    
    NSUInteger downloadID = [nDownloader startDownload:testUrl];
    int progress = [nDownloader checkStatus:downloadID];
    XCTAssertNotEqual(progress, -1);
    
    while (progress != 100) {
        progress = [nDownloader checkStatus:downloadID];
        
        XCTAssertNotEqual(progress, -1);
        [NSThread sleepForTimeInterval: 1];
    }
    
    XCTAssertEqual(progress, 100);
}

@end
