//
// Copyright (c) 2014 Mixpanel. All rights reserved.
//

//   Portions Copyright 2012 Square Inc.
//
//   Licensed under the Apache License, Version 2.0 (the "License");
//   you may not use this file except in compliance with the License.
//   You may obtain a copy of the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in writing, software
//   distributed under the License is distributed on an "AS IS" BASIS,
//   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//   See the License for the specific language governing permissions and
//   limitations under the License.
//

#import <Foundation/Foundation.h>
#import <Security/SecCertificate.h>

typedef enum {
    AloomaWebSocketStateConnecting = 0,
    AloomaWebSocketStateOpen = 1,
    AloomaWebSocketStateClosing = 2,
    AloomaWebSocketStateClosed = 3,
} AloomaWebSocketReadyState;

@class AloomaWebSocket;

extern NSString *const AloomaWebSocketErrorDomain;

#pragma mark - AloomaWebSocketDelegate

@protocol AloomaWebSocketDelegate;

#pragma mark - AloomaWebSocket

@interface AloomaWebSocket : NSObject <NSStreamDelegate>

@property (nonatomic, assign) id <AloomaWebSocketDelegate> delegate;

@property (nonatomic, readonly) AloomaWebSocketReadyState readyState;
@property (nonatomic, readonly, retain) NSURL *url;

// This returns the negotiated protocol.
// It will be nil until after the handshake completes.
@property (nonatomic, readonly, copy) NSString *protocol;

// Protocols should be an array of strings that turn into Sec-WebSocket-Protocol.
- (id)initWithURLRequest:(NSURLRequest *)request protocols:(NSArray *)protocols;
- (id)initWithURLRequest:(NSURLRequest *)request;

// Some helper constructors.
- (id)initWithURL:(NSURL *)url protocols:(NSArray *)protocols;
- (id)initWithURL:(NSURL *)url;

// Delegate queue will be dispatch_main_queue by default.
// You cannot set both OperationQueue and dispatch_queue.
- (void)setDelegateOperationQueue:(NSOperationQueue*) queue;
- (void)setDelegateDispatchQueue:(dispatch_queue_t) queue;

// By default, it will schedule itself on +[NSRunLoop mp_networkRunLoop] using defaultModes.
- (void)scheduleInRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode;
- (void)unscheduleFromRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode;

// MPWebSockets are intended for one-time-use only.  Open should be called once and only once.
- (void)open;

- (void)close;
- (void)closeWithCode:(NSInteger)code reason:(NSString *)reason;

// Send a UTF8 String or Data.
- (void)send:(id)data;

@end

#pragma mark - AloomaWebSocketDelegate

@protocol AloomaWebSocketDelegate <NSObject>

// message will either be an NSString if the server is using text
// or NSData if the server is using binary.
- (void)webSocket:(AloomaWebSocket *)webSocket didReceiveMessage:(id)message;

@optional

- (void)webSocketDidOpen:(AloomaWebSocket *)webSocket;
- (void)webSocket:(AloomaWebSocket *)webSocket didFailWithError:(NSError *)error;
- (void)webSocket:(AloomaWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean;

@end

#pragma mark - NSURLRequest (CertificateAdditions)

@interface NSURLRequest (CertificateAdditions)

@property (nonatomic, retain, readonly) NSArray *mp_SSLPinnedCertificates;

@end

#pragma mark - NSMutableURLRequest (CertificateAdditions)

@interface NSMutableURLRequest (CertificateAdditions)

@property (nonatomic, retain) NSArray *mp_SSLPinnedCertificates;

@end

#pragma mark - NSRunLoop (SRWebSocket)

@interface NSRunLoop (AloomaWebSocket)

+ (NSRunLoop *)mp_networkRunLoop;

@end
