//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import "MPABTestDesignerConnection.h"
#import "MPABTestDesignerMessage.h"
#import "MPABTestDesignerSnapshotResponseMessage.h"
#import "MPABTestDesignerSnapshotRequestMessage.h"
#import "MPABTestDesignerChangeRequestMessage.h"
#import "MPABTestDesignerDeviceInfoRequestMessage.h"
#import "MPABTestDesignerTweakRequestMessage.h"
#import "MPABTestDesignerClearRequestMessage.h"
#import "MPABTestDesignerDisconnectMessage.h"

#ifdef MESSAGING_DEBUG
#define MessagingDebug(...) NSLog(__VA_ARGS__)
#else
#define MessagingDebug(...)
#endif

NSString * const kSessionVariantKey = @"session_variant";

@interface MPABTestDesignerConnection () <MPWebSocketDelegate>
@end

@implementation MPABTestDesignerConnection
{
    NSURL *_url;
    NSMutableDictionary *_session;
    NSDictionary *_typeToMessageClassMap;
    MPWebSocket *_webSocket;
    NSOperationQueue *_commandQueue;
    UIView *_recordingView;
}

- (id)initWithURL:(NSURL *)url
{
    self = [super init];
    if (self)
    {
        _typeToMessageClassMap = @{
            MPABTestDesignerSnapshotRequestMessageType   : [MPABTestDesignerSnapshotRequestMessage class],
            MPABTestDesignerChangeRequestMessageType     : [MPABTestDesignerChangeRequestMessage class],
            MPABTestDesignerDeviceInfoRequestMessageType : [MPABTestDesignerDeviceInfoRequestMessage class],
            MPABTestDesignerTweakRequestMessageType      : [MPABTestDesignerTweakRequestMessage class],
            MPABTestDesignerClearRequestMessageType      : [MPABTestDesignerClearRequestMessage class],
            MPABTestDesignerDisconnectMessageType        : [MPABTestDesignerDisconnectMessage class],
        };

        _sessionEnded = NO;
        _connected = NO;
        _session = [[NSMutableDictionary alloc] init];
        _url = url;

        _commandQueue = [[NSOperationQueue alloc] init];
        _commandQueue.maxConcurrentOperationCount = 1;
        _commandQueue.suspended = YES;

        [self open];
    }

    return self;
}

- (void)open
{
    MessagingDebug(@"Attempting to open WebSocket to: %@", _url);
    _webSocket = [[MPWebSocket alloc] initWithURL:_url];
    _webSocket.delegate = self;
    [_webSocket open];
}

- (void)close
{
    [_webSocket close];
}

- (void)dealloc
{
    _webSocket.delegate = nil;
    [self close];
}

- (void)setSessionObject:(id)object forKey:(NSString *)key
{
    NSParameterAssert(key != nil);

    @synchronized (_session)
    {
        _session[key] = object ?: [NSNull null];
    }
}

- (id)sessionObjectForKey:(NSString *)key
{
    NSParameterAssert(key != nil);

    @synchronized (_session)
    {
        id object = _session[key];
        return [object isEqual:[NSNull null]] ? nil : object;
    }
}

- (void)sendMessage:(id<MPABTestDesignerMessage>)message
{
    MessagingDebug(@"Sending message: %@", [message debugDescription]);
    NSString *jsonString = [[NSString alloc] initWithData:[message JSONData] encoding:NSUTF8StringEncoding];
    [_webSocket send:jsonString];
}

- (id <MPABTestDesignerMessage>)designerMessageForMessage:(id)message
{
    MessagingDebug(@"raw message: %@", message);

    NSParameterAssert([message isKindOfClass:[NSString class]] || [message isKindOfClass:[NSData class]]);

    id <MPABTestDesignerMessage> designerMessage = nil;

    NSData *jsonData = [message isKindOfClass:[NSString class]] ? [(NSString *)message dataUsingEncoding:NSUTF8StringEncoding] : message;

    NSError *error = nil;
    id jsonObject = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    if ([jsonObject isKindOfClass:[NSDictionary class]])
    {
        NSDictionary *messageDictionary = (NSDictionary *)jsonObject;
        NSString *type = messageDictionary[@"type"];
        NSDictionary *payload = messageDictionary[@"payload"];

        designerMessage = [_typeToMessageClassMap[type] messageWithType:type payload:payload];
    }
    else
    {
        MessagingDebug(@"Badly formed socket message expected JSON dictionary: %@", error);
    }

    return designerMessage;
}

#pragma mark - MPWebSocketDelegate Methods

- (void)webSocket:(MPWebSocket *)webSocket didReceiveMessage:(id)message
{
    id<MPABTestDesignerMessage> designerMessage = [self designerMessageForMessage:message];
    MessagingDebug(@"WebSocket received message: %@", [designerMessage debugDescription]);

    NSOperation *commandOperation = [designerMessage responseCommandWithConnection:self];

    if (commandOperation)
    {
        [_commandQueue addOperation:commandOperation];
    }
}

- (void)webSocketDidOpen:(MPWebSocket *)webSocket
{
    MessagingDebug(@"WebSocket did open.");
    self.connected = YES;
    _commandQueue.suspended = NO;
    [self showConnectedView];
}

- (void)webSocket:(MPWebSocket *)webSocket didFailWithError:(NSError *)error
{
    MessagingDebug(@"WebSocket did fail with error: %@", error);
    _commandQueue.suspended = YES;
    [_commandQueue cancelAllOperations];
    [self hideConnectedView];
    self.connected = NO;
    [self reconnect:YES];
}

- (void)webSocket:(MPWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
    MessagingDebug(@"WebSocket did close with code '%d' reason '%@'.", (int)code, reason);

    _commandQueue.suspended = YES;
    [_commandQueue cancelAllOperations];
    [self hideConnectedView];
    self.connected = NO;
    [self reconnect:YES];
}

- (void)reconnect:(BOOL)first
{
    static int retries = 0;
    if (self.sessionEnded || self.connected || retries >= 10) {
        // If we deliberately closed the connection, or are already connected
        // or we tried too many times, then reset the retry count and stop.
        retries = 0;
    } else if(first ^ (retries > 0)) {
        // If either this is the first try at reconnecting, or we are already in a
        // reconnect cycle (but not both). Then continue trying.
        MessagingDebug(@"Attempting to reconnect, attempt %d", retries);
        [self open];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MIN(pow(2, retries),10) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self reconnect:NO];
        });
        retries++;
    }
}

- (void)showConnectedView
{
    if(!_recordingView) {
        UIWindow *mainWindow = [[UIApplication sharedApplication] delegate].window;
        _recordingView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, mainWindow.frame.size.width, 1.0)];
        _recordingView.backgroundColor = [UIColor colorWithRed:4/255.0f green:180/255.0f blue:4/255.0f alpha:1.0];
        [mainWindow addSubview:_recordingView];
        [mainWindow bringSubviewToFront:_recordingView];
    }
}

- (void)hideConnectedView
{
    if (_recordingView) {
        [_recordingView removeFromSuperview];
    }
    _recordingView = nil;
}

@end

