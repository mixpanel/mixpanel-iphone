//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import "Mixpanel.h"
#import "MixpanelPrivate.h"
#import "MPABTestDesignerChangeRequestMessage.h"
#import "MPABTestDesignerClearRequestMessage.h"
#import "MPABTestDesignerConnection.h"
#import "MPABTestDesignerDeviceInfoRequestMessage.h"
#import "MPABTestDesignerDisconnectMessage.h"
#import "MPABTestDesignerMessage.h"
#import "MPABTestDesignerSnapshotRequestMessage.h"
#import "MPABTestDesignerSnapshotResponseMessage.h"
#import "MPABTestDesignerTweakRequestMessage.h"
#import "MPDesignerEventBindingMessage.h"
#import "MPDesignerSessionCollection.h"
#import "MPLogger.h"
#import "MPSwizzler.h"

NSString * const kSessionVariantKey = @"session_variant";
static NSString * const kStartLoadingAnimationKey = @"MPConnectivityBarLoadingAnimation";
static NSString * const kFinishLoadingAnimationKey = @"MPConnectivityBarFinishLoadingAnimation";

@interface MPABTestDesignerConnection () <MPWebSocketDelegate>
@property (strong, nonatomic) UIWindow *connectivityIndicatorWindow;
@end

@implementation MPABTestDesignerConnection
{
    /* The difference between _open and _connected is that open
     is set when the socket is open, and _connected is set when
     we actually have started sending/receiving messages from
     the server. A connection can become _open/not _open in quick
     succession if the websocket proxy rejects the request, but
     we will only try and reconnect if we were actually _connected.
     */
    BOOL _open;
    BOOL _connected;

    NSURL *_url;
    NSMutableDictionary *_session;
    NSDictionary *_typeToMessageClassMap;
    MPWebSocket *_webSocket;
    NSOperationQueue *_commandQueue;
    UIView *_recordingView;
    CALayer *_indeterminateLayer;
    void (^_connectCallback)();
    void (^_disconnectCallback)();
}

- (instancetype)initWithURL:(NSURL *)url keepTrying:(BOOL)keepTrying connectCallback:(void (^)())connectCallback disconnectCallback:(void (^)())disconnectCallback
{
    self = [super init];
    if (self) {
        _typeToMessageClassMap = @{
            MPABTestDesignerSnapshotRequestMessageType   : [MPABTestDesignerSnapshotRequestMessage class],
            MPABTestDesignerChangeRequestMessageType     : [MPABTestDesignerChangeRequestMessage class],
            MPABTestDesignerDeviceInfoRequestMessageType : [MPABTestDesignerDeviceInfoRequestMessage class],
            MPABTestDesignerTweakRequestMessageType      : [MPABTestDesignerTweakRequestMessage class],
            MPABTestDesignerClearRequestMessageType      : [MPABTestDesignerClearRequestMessage class],
            MPABTestDesignerDisconnectMessageType        : [MPABTestDesignerDisconnectMessage class],
            MPDesignerEventBindingRequestMessageType     : [MPDesignerEventBindingRequestMessage class],
        };

        _open = NO;
        _connected = NO;
        _sessionEnded = NO;
        _session = [NSMutableDictionary dictionary];
        _url = url;
        _connectCallback = connectCallback;
        _disconnectCallback = disconnectCallback;

        _commandQueue = [[NSOperationQueue alloc] init];
        _commandQueue.maxConcurrentOperationCount = 1;
        _commandQueue.suspended = YES;

        if (keepTrying) {
            [self open:YES maxInterval:30 maxRetries:40];
        } else {
            [self open:YES maxInterval:0 maxRetries:0];
        }
    }

    return self;
}

- (instancetype)initWithURL:(NSURL *)url
{
    return [self initWithURL:url keepTrying:NO connectCallback:nil disconnectCallback:nil];
}


- (void)open:(BOOL)initiate maxInterval:(int)maxInterval maxRetries:(int)maxRetries
{
    static int retries = 0;
    BOOL inRetryLoop = retries > 0;

    MPLogDebug(@"In open. initiate = %d, retries = %d, maxRetries = %d, maxInterval = %d, connected = %d", initiate, retries, maxRetries, maxInterval, _connected);

    if (self.sessionEnded || _connected || (inRetryLoop && retries >= maxRetries) ) {
        // break out of retry loop if any of the success conditions are met.
        retries = 0;
    } else if (initiate ^ inRetryLoop) {
        // If we are initiating a new connection, or we are already in a
        // retry loop (but not both). Then open a socket.
        if (!_open) {
            MPLogDebug(@"Attempting to open WebSocket to: %@, try %d/%d ", _url, retries, maxRetries);
            _open = YES;
            _webSocket = [[MPWebSocket alloc] initWithURL:_url];
            _webSocket.delegate = self;
            [_webSocket open];
        }
        if (retries < maxRetries) {
            __weak MPABTestDesignerConnection *weakSelf = self;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MIN(pow(1.4, retries), maxInterval) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                MPABTestDesignerConnection *strongSelf = weakSelf;
                [strongSelf open:NO maxInterval:maxInterval maxRetries:maxRetries];
            });
            retries++;
        }
    }
}

- (void)close
{
    [_webSocket close];
    for (id value in _session.allValues) {
        if ([value conformsToProtocol:@protocol(MPDesignerSessionCollection)]) {
            [value cleanup];
        }
    }
    _session = nil;
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
    if (_connected) {
        MPLogDebug(@"Sending message: %@", [message debugDescription]);
        NSString *jsonString = [[NSString alloc] initWithData:[message JSONData] encoding:NSUTF8StringEncoding];
        [_webSocket send:jsonString];
    } else {
        MPLogDebug(@"Not sending message as we are not connected: %@", [message debugDescription]);
    }
}

- (id <MPABTestDesignerMessage>)designerMessageForMessage:(id)message
{
    MPLogInfo(@"raw message: %@", message);

    NSParameterAssert([message isKindOfClass:[NSString class]] || [message isKindOfClass:[NSData class]]);

    id <MPABTestDesignerMessage> designerMessage = nil;

    NSData *jsonData = [message isKindOfClass:[NSString class]] ? [(NSString *)message dataUsingEncoding:NSUTF8StringEncoding] : message;

    NSError *error = nil;
    id jsonObject = [NSJSONSerialization JSONObjectWithData:jsonData options:(NSJSONReadingOptions)0 error:&error];
    if ([jsonObject isKindOfClass:[NSDictionary class]]) {
        NSDictionary *messageDictionary = (NSDictionary *)jsonObject;
        NSString *type = messageDictionary[@"type"];
        NSDictionary *payload = messageDictionary[@"payload"];

        designerMessage = [_typeToMessageClassMap[type] messageWithType:type payload:payload];
    } else {
        MPLogWarning(@"Badly formed socket message expected JSON dictionary: %@", error);
    }

    return designerMessage;
}

#pragma mark - MPWebSocketDelegate Methods

- (void)webSocket:(MPWebSocket *)webSocket didReceiveMessage:(id)message
{
    if (!_connected) {
        _connected = YES;
        [self showConnectedViewWithLoading:NO];
        if (_connectCallback) {
            _connectCallback();
        }
    }
    id<MPABTestDesignerMessage> designerMessage = [self designerMessageForMessage:message];
    MPLogInfo(@"WebSocket received message: %@", [designerMessage debugDescription]);
    NSOperation *commandOperation = [designerMessage responseCommandWithConnection:self];

    if (commandOperation) {
        [_commandQueue addOperation:commandOperation];
    }
}

- (void)webSocketDidOpen:(MPWebSocket *)webSocket
{
    MPLogInfo(@"WebSocket %@ did open.", webSocket);
    _commandQueue.suspended = NO;
    [self showConnectedViewWithLoading:YES];
}

- (void)webSocket:(MPWebSocket *)webSocket didFailWithError:(NSError *)error
{
    MPLogError(@"WebSocket did fail with error: %@", error);
    _commandQueue.suspended = YES;
    [_commandQueue cancelAllOperations];
    [self hideConnectedView];
    _open = NO;
    if (_connected) {
        _connected = NO;
        [self open:YES maxInterval:10 maxRetries:10];
        if (_disconnectCallback) {
            _disconnectCallback();
        }
    }
}

- (void)webSocket:(MPWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
    MPLogDebug(@"WebSocket did close with code '%d' reason '%@'.", (int)code, reason);

    _commandQueue.suspended = YES;
    [_commandQueue cancelAllOperations];
    [self hideConnectedView];
    _open = NO;
    if (_connected) {
        _connected = NO;
        [self open:YES maxInterval:10 maxRetries:10];
        if (_disconnectCallback) {
            _disconnectCallback();
        }
    }
}

- (void)showConnectedViewWithLoading:(BOOL)isLoading {
    if (!self.connectivityIndicatorWindow) {
        UIWindow *mainWindow = [[Mixpanel sharedUIApplication] delegate].window;
        self.connectivityIndicatorWindow = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, mainWindow.frame.size.width, 4.f)];
        self.connectivityIndicatorWindow.backgroundColor = [UIColor clearColor];
        self.connectivityIndicatorWindow.windowLevel = UIWindowLevelAlert;
        self.connectivityIndicatorWindow.alpha = 0;
        self.connectivityIndicatorWindow.hidden = NO;
        
        _recordingView = [[UIView alloc] initWithFrame:self.connectivityIndicatorWindow.frame];
        _recordingView.backgroundColor = [UIColor clearColor];
        _indeterminateLayer = [CALayer layer];
        _indeterminateLayer.backgroundColor = [UIColor colorWithRed:1/255.0 green:179/255.0 blue:109/255.0 alpha:1.0].CGColor;
        _indeterminateLayer.frame = CGRectMake(0, 0, 0, 4.0f);
        [_recordingView.layer addSublayer:_indeterminateLayer];
        [self.connectivityIndicatorWindow addSubview:_recordingView];
        [self.connectivityIndicatorWindow bringSubviewToFront:_recordingView];
        
        [UIView animateWithDuration:0.3 animations:^{
            self.connectivityIndicatorWindow.alpha = 1;
        }];
    }
    [self animateConnecting:isLoading];
}

- (void)animateConnecting:(BOOL)isLoading {
    if (isLoading) {
        CABasicAnimation* myAnimation = [CABasicAnimation animationWithKeyPath:@"bounds.size.width"];
        myAnimation.duration = 10.f;
        myAnimation.fromValue = @0;
        myAnimation.toValue = @(_connectivityIndicatorWindow.bounds.size.width * 1.9f);
        myAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        myAnimation.fillMode = kCAFillModeForwards;
        myAnimation.removedOnCompletion = NO;
        [_indeterminateLayer addAnimation:myAnimation forKey:kStartLoadingAnimationKey];
    } else {
        [_indeterminateLayer removeAnimationForKey:kStartLoadingAnimationKey];
        CABasicAnimation* myAnimation = [CABasicAnimation animationWithKeyPath:@"bounds.size.width"];
        myAnimation.duration = 0.4f;
        myAnimation.fromValue = @([[_indeterminateLayer.presentationLayer valueForKeyPath: @"bounds.size.width"] floatValue]);
        myAnimation.toValue = @(_connectivityIndicatorWindow.bounds.size.width * 2.f);
        myAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        myAnimation.fillMode = kCAFillModeForwards;
        myAnimation.removedOnCompletion = NO;
        [_indeterminateLayer addAnimation:myAnimation forKey:kFinishLoadingAnimationKey];
    }
}

- (void)hideConnectedView {
    if (self.connectivityIndicatorWindow) {
        [_indeterminateLayer removeFromSuperlayer];
        [_recordingView removeFromSuperview];
        self.connectivityIndicatorWindow.hidden = YES;
    }
    self.connectivityIndicatorWindow = nil;
}

@end

