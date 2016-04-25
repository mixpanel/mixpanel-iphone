//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import "Mixpanel.h"
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

@interface MPABTestDesignerConnection () <MPWebSocketDelegate>
@property (strong, nonatomic) UIWindow *bubbleWindow;

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
    UIImageView *_bubbleView;
    void (^_connectCallback)();
    void (^_disconnectCallback)();
    CGPoint prevPoint;
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
        _session = [[NSMutableDictionary alloc] init];
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

    MessagingDebug(@"In open. initiate = %d, retries = %d, maxRetries = %d, maxInterval = %d, connected = %d", initiate, retries, maxRetries, maxInterval, _connected);

    if (self.sessionEnded || _connected || (inRetryLoop && retries >= maxRetries) ) {
        // break out of retry loop if any of the success conditions are met.
        retries = 0;
    } else if (initiate ^ inRetryLoop) {
        // If we are initiating a new connection, or we are already in a
        // retry loop (but not both). Then open a socket.
        if (!_open) {
            MessagingDebug(@"Attempting to open WebSocket to: %@, try %d/%d ", _url, retries, maxRetries);
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
    for (NSString *key in [_session keyEnumerator]) {
        id value = [_session valueForKey:key];
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
        MessagingDebug(@"Sending message: %@", [message debugDescription]);
        NSString *jsonString = [[NSString alloc] initWithData:[message JSONData] encoding:NSUTF8StringEncoding];
        [_webSocket send:jsonString];
    } else {
        MessagingDebug(@"Not sending message as we are not connected: %@", [message debugDescription]);
    }
}

- (id <MPABTestDesignerMessage>)designerMessageForMessage:(id)message
{
    MessagingDebug(@"raw message: %@", message);

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
        MessagingDebug(@"Badly formed socket message expected JSON dictionary: %@", error);
    }

    return designerMessage;
}

#pragma mark - MPWebSocketDelegate Methods

- (void)webSocket:(MPWebSocket *)webSocket didReceiveMessage:(id)message
{
    if (!_connected) {
        _connected = YES;
        [self showConnectedView];
        if (_connectCallback) {
            _connectCallback();
        }
    }
    id<MPABTestDesignerMessage> designerMessage = [self designerMessageForMessage:message];
    MessagingDebug(@"WebSocket received message: %@", [designerMessage debugDescription]);

    NSOperation *commandOperation = [designerMessage responseCommandWithConnection:self];

    if (commandOperation) {
        [_commandQueue addOperation:commandOperation];
    }
}

- (void)webSocketDidOpen:(MPWebSocket *)webSocket
{
    MessagingDebug(@"WebSocket %@ did open.", webSocket);
    _commandQueue.suspended = NO;
    [self showConnectedBubble];
}

- (void)webSocket:(MPWebSocket *)webSocket didFailWithError:(NSError *)error
{
    MessagingDebug(@"WebSocket did fail with error: %@", error);
    _commandQueue.suspended = YES;
    [_commandQueue cancelAllOperations];
    [self hideConnectedView];
    [self hideBubbleView];
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
    MessagingDebug(@"WebSocket did close with code '%d' reason '%@'.", (int)code, reason);

    _commandQueue.suspended = YES;
    [_commandQueue cancelAllOperations];
    [self hideConnectedView];
    [self hideBubbleView];
    _open = NO;
    if (_connected) {
        _connected = NO;
        [self open:YES maxInterval:10 maxRetries:10];
        if (_disconnectCallback) {
            _disconnectCallback();
        }
    }
}

- (void)showConnectedBubble
{
    if (!self.bubbleWindow) {
        self.bubbleWindow = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 50, 50)];
        self.bubbleWindow.backgroundColor = [UIColor clearColor];
        self.bubbleWindow.clipsToBounds = true;
        self.bubbleWindow.layer.cornerRadius = self.bubbleWindow.frame.size.width/2;
        self.bubbleWindow.windowLevel = UIWindowLevelAlert;
        self.bubbleWindow.backgroundColor = [UIColor colorWithRed:99/255.0 green:121/255.0 blue:151/255.0 alpha:1];
        self.bubbleWindow.alpha = 0;
        [self.bubbleWindow setHidden:NO];
//        [self.bubbleWindow  makeKeyAndVisible];
        _bubbleView = [[UIImageView alloc] initWithFrame:self.bubbleWindow.frame];
        _bubbleView.clipsToBounds = true;
        _bubbleView.layer.cornerRadius = _bubbleView.frame.size.width/2;
        _bubbleView.image = [UIImage imageNamed:@"Icon-72"];
        [self.bubbleWindow addSubview:_bubbleView];
        UILabel *explanatoryText = [[UILabel alloc] initWithFrame:CGRectMake(15, [UIScreen mainScreen].bounds.size.height/2 - 75, [UIScreen mainScreen].bounds.size.width - 30, 150)];
        explanatoryText.numberOfLines = 0;
        explanatoryText.text = @"Welcome to our A/B testing edit mode. If you are not the one trying to connect through the web interface, please force close your app now. Through the web interface you can tap on different UI frames and edit their behavior. Feel free to navigate to other screens you want to edit using your device.";
        explanatoryText.font = [UIFont fontWithName:@"Avenir Next" size:13.f];
        explanatoryText.textColor = [UIColor whiteColor];
        explanatoryText.textAlignment = NSTextAlignmentCenter;
        [self.bubbleWindow addSubview:explanatoryText];

        UIPanGestureRecognizer *panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(moveMixpanelBubble:)];
        [self.bubbleWindow addGestureRecognizer:panRecognizer];

        UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapBubble:)];
        [self.bubbleWindow addGestureRecognizer:tapRecognizer];

        [UIView animateWithDuration:0.3 animations:^{
            self.bubbleWindow.alpha = 1;
        }];
    }
}

- (void)didTapBubble:(UITapGestureRecognizer *)gesture {
    if (!CGRectEqualToRect(self.bubbleWindow.frame, [UIScreen mainScreen].bounds)) {
        [UIView animateWithDuration:0.3 animations:^{
            self.bubbleWindow.frame = [UIScreen mainScreen].bounds;
            _bubbleView.alpha = 0;
            for (UIGestureRecognizer *g in self.bubbleWindow.gestureRecognizers) {
                if ([g isKindOfClass:[UIPanGestureRecognizer class]]) {
                    g.enabled = NO;
                }
            }
        }];
    } else {
        [UIView animateWithDuration:0.3 animations:^{
            self.bubbleWindow.frame = CGRectMake(0, 0, 50, 50);
            _bubbleView.alpha = 1;
            for (UIGestureRecognizer *g in self.bubbleWindow.gestureRecognizers) {
                if ([g isKindOfClass:[UIPanGestureRecognizer class]]) {
                    g.enabled = YES;
                }
            }
        }];
    }
}

- (void)moveMixpanelBubble:(UIPanGestureRecognizer *)gesture
{
    CGPoint currPoint = [gesture locationInView:gesture.view];
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan: {
            prevPoint = currPoint;
            break;
        }
        case UIGestureRecognizerStateEnded: {
            UIWindow *mainWindow = [[UIApplication sharedApplication] delegate].window;
            CGPoint velocity = [gesture velocityInView:mainWindow];
            CGFloat magnitude = sqrt((velocity.x * velocity.x) + (velocity.y * velocity.y));
            CGFloat slideMult = magnitude / 200;

            CGFloat slideFactor = 0.1 * slideMult; // Increase for more slide
            CGPoint finalPoint = CGPointMake(gesture.view.center.x + (velocity.x * slideFactor),
                                             gesture.view.center.y + (velocity.y * slideFactor));
            finalPoint.x = MIN(MAX(finalPoint.x, gesture.view.frame.size.width/2), mainWindow.bounds.size.width - gesture.view.frame.size.width/2);
            finalPoint.y = MIN(MAX(finalPoint.y, gesture.view.frame.size.height/2), mainWindow.bounds.size.height - gesture.view.frame.size.height/2);

            [UIView animateWithDuration:slideFactor delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                gesture.view.center = finalPoint;
            } completion:nil];
            break;
        }
        case UIGestureRecognizerStateChanged: {
            gesture.view.center = CGPointMake(gesture.view.center.x + (currPoint.x - prevPoint.x), gesture.view.center.y + (currPoint.y - prevPoint.y));
            break;
        }
        default:
            break;
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

- (void)hideBubbleView
{
    if (self.bubbleWindow) {
        [self.bubbleWindow removeFromSuperview];
    }
    self.bubbleWindow = nil;
}

- (void)hideConnectedView
{
    if (_recordingView) {
        [_recordingView removeFromSuperview];
    }
    _recordingView = nil;
}

@end

