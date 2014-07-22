//
//  BCHDataManager.m
//  Hack
//
//  Created by Brian Chu on 7/20/14.
//  Copyright (c) 2014 Brian. All rights reserved.
//

#import <SocketRocket/SRWebSocket.h>
#import <AFNetworking/AFNetworking.h>
#import "BCHDataManager.h"
@import WebKit;

static NSString *const BCH_API_HOST = @"http://example.com";
static NSArray *BCH_API_HOST_TESTS;

static NSString *const BCH_API_PATH_SOCKET = @"/socket";
static NSString *const BCH_API_PATH_IMAGE = @"/screencast";
static NSString *const BCH_API_PATH_HTTP = @"/update";

@interface BCHDataManager () <SRWebSocketDelegate, WKScriptMessageHandler>
@end

@implementation BCHDataManager

+ (void)initialize
{
    BCH_API_HOST_TESTS = @[
                           @"http://sdgflsdflg.ngrok.com"
                           ];
}

+ (instancetype)sharedInstance
{
    static BCHDataManager *shared;
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        shared = [[self alloc] initPrivate];
    });
    return shared;
}

- (instancetype)initPrivate
{
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidBecomeActive:)
                                                     name:UIApplicationDidBecomeActiveNotification object:nil];


//        self.webSocket = [self createWebSocket:[BCH_API_HOST stringByAppendingString:BCH_API_PATH_SOCKET]];
        self.webSocketTests = [NSMutableArray array];
        for (NSString *testHost in BCH_API_HOST_TESTS) {
            [self.webSocketTests addObject:[self createWebSocket:[testHost stringByAppendingString:BCH_API_PATH_SOCKET]]];
        }
        self.httpManager = [AFHTTPRequestOperationManager manager];
        self.httpManager.requestSerializer = [AFJSONRequestSerializer serializer];
    }
    return self;
}



- (SRWebSocket *)createWebSocket:(NSString *)url
{
    SRWebSocket *socket = [[SRWebSocket alloc] initWithURL:[NSURL URLWithString:url]];
    socket.delegate = self;
    [socket open];
    return socket;
}

- (void)postMotionUpdate:(MotionData)data otherParams:(NSDictionary *)otherParams
{
    NSDictionary *parameters = @{
                                 @"rotationRateX": @(data.rotX),
                                 @"rotationRateY": @(data.rotY),
                                 @"rotationRateZ": @(data.rotZ),
                                 @"quaternion":@[@(data.x), @(data.y), @(data.z), @(data.w)],
                                 @"accelerationX":@(data.accelX),
                                 @"accelerationY":@(data.accelY),
                                 @"accelerationZ":@(data.accelZ)
                                 };
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:parameters options:0 error:nil];
//    [self postMotionUpdateHelperWithData:jsonData parameters:parameters socket:self.webSocket host:BCH_API_HOST];
    
    for (NSUInteger i = 0; i < self.webSocketTests.count; i++ ) {
        [self postMotionUpdateHelperWithData:jsonData parameters:parameters socket:self.webSocketTests[i] host:BCH_API_HOST_TESTS[i]];
    }
}

- (void)postMotionUpdateHelperWithData:(NSData *)data parameters:(NSDictionary *)parameters socket:(SRWebSocket *)socket host:(NSString *)host
{
    if (socket.readyState == SR_OPEN) {
        [socket send:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
    }
    else {
        [self.httpManager POST:[host stringByAppendingString:BCH_API_PATH_HTTP] parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            //        NSLog(@"\nError: %@", error);
        }];
    }
}

- (void)postScreencastImageData:(NSData *)data
{
//    [self postScreencastImageDataHelper:data socket:self.webSocket host:BCH_API_HOST];

    for (NSUInteger i = 0; i < self.webSocketTests.count; i++ ) {
//        [self postScreencastImageDataHelper:data socket:self.webSocketTests[i] host:BCH_API_HOST_TESTS[i]];
    }
}

- (void)postScreencastImageDataHelper:(NSData *)data socket:(SRWebSocket *)socket host:(NSString *)host
{
    if (socket.readyState == SR_OPEN) {
        [socket send:data];
    }
    else {
        NSMutableURLRequest *request = [[AFHTTPRequestSerializer serializer] multipartFormRequestWithMethod:@"POST" URLString:[host stringByAppendingString:BCH_API_PATH_IMAGE] parameters:nil constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
            [formData appendPartWithFileData:data name:@"image" fileName:@"original.jpg" mimeType:@"image/jpeg"];
        } error:nil];
        
        AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
        [self.httpManager.operationQueue addOperation:operation];
    }
}

- (void)attemptReconnection: (SRWebSocket *)webSocket
{
    CGFloat seconds = 3;
    dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * seconds);
    dispatch_after(delay, dispatch_get_main_queue(), ^(void){
        //    if (!self.webSocket) {
        //        self.webSocket = [self createWebSocket:[BCH_API_HOST stringByAppendingString:BCH_API_PATH_SOCKET]];
        //    }
        NSInteger idx = [self.webSocketTests indexOfObject:webSocket];
        if (idx >= 0 && idx < self.webSocketTests.count) {
            [self.webSocketTests replaceObjectAtIndex:idx withObject:[self createWebSocket:[webSocket.url absoluteString]]];
        }
    });
}

- (void)applicationDidBecomeActive: (NSNotification *)notification
{
    [self attemptReconnection:nil];
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error
{
//    NSLog(@"websocket failed: %@", error);
    [self attemptReconnection:webSocket];
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket
{
    NSLog(@"opened socket: %@", webSocket);
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message
{
    NSLog(@"received");
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
    NSLog(@"closed: code:%li, reason:%@", (long)code, reason);
}
@end
