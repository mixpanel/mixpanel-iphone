//
//  MixpanelExceptionHandler.m
//  HelloMixpanel
//
//  Created by Sam Green on 7/28/15.
//  Copyright (c) 2015 Mixpanel. All rights reserved.
//

#import "MixpanelExceptionHandler.h"
#import "Mixpanel.h"
#import "MixpanelPrivate.h"
#import "MPLogger.h"
#include <libkern/OSAtomic.h>
#include <execinfo.h>

NSString * const UncaughtExceptionHandlerSignalExceptionName = @"UncaughtExceptionHandlerSignalExceptionName";
NSString * const UncaughtExceptionHandlerSignalKey = @"UncaughtExceptionHandlerSignalKey";
NSString * const UncaughtExceptionHandlerAddressesKey = @"UncaughtExceptionHandlerAddressesKey";

volatile int32_t UncaughtExceptionCount = 0;
const int32_t UncaughtExceptionMaximum = 10;

const NSInteger UncaughtExceptionHandlerSkipAddressCount = 4;
const NSInteger UncaughtExceptionHandlerReportAddressCount = 5;

@interface MixpanelExceptionHandler ()

@property (nonatomic) NSUncaughtExceptionHandler *defaultExceptionHandler;
@property (nonatomic, unsafe_unretained) struct sigaction *prev_signal_handlers;
@property (nonatomic, strong) NSHashTable *mixpanelInstances;

@end

@implementation MixpanelExceptionHandler

+ (instancetype)sharedHandler {
    static MixpanelExceptionHandler *gSharedHandler = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gSharedHandler = [[MixpanelExceptionHandler alloc] init];
    });
    return gSharedHandler;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // Create a hash table of weak pointers to mixpanel instances
        _mixpanelInstances = [NSHashTable weakObjectsHashTable];
        
        _prev_signal_handlers = calloc(NSIG, sizeof(struct sigaction));

        // Install our handler
        [self setupHandlers];
    }
    return self;
}

- (void)dealloc {
    free(_prev_signal_handlers);
}

- (void)setupHandlers {
    _defaultExceptionHandler = NSGetUncaughtExceptionHandler();
    NSSetUncaughtExceptionHandler(&MPHandleException);

    struct sigaction action;
    sigemptyset(&action.sa_mask);
    action.sa_flags = SA_SIGINFO;
    action.sa_sigaction = &MPSignalHandler;
    int signals[] = {SIGABRT, SIGILL, SIGSEGV, SIGFPE, SIGBUS, SIGPIPE};
    for (int i = 0; i < sizeof(signals) / sizeof(int); i++) {
        struct sigaction prev_action;
        int err = sigaction(signals[i], &action, &prev_action);
        if (err == 0) {
            memcpy(_prev_signal_handlers + signals[i], &prev_action, sizeof(prev_action));
        } else {
            NSLog(@"Errored while trying to set up sigaction for signal %d", signals[i]);
        }
    }
}

- (void)addMixpanelInstance:(Mixpanel *)instance {
    NSParameterAssert(instance != nil);
    
    [self.mixpanelInstances addObject:instance];
}

void MPSignalHandler(int signal, struct __siginfo *info, void *context) {
    MixpanelExceptionHandler *handler = [MixpanelExceptionHandler sharedHandler];

    int32_t exceptionCount = OSAtomicIncrement32(&UncaughtExceptionCount);
    if (exceptionCount <= UncaughtExceptionMaximum) {
        NSDictionary *userInfo = @{UncaughtExceptionHandlerSignalKey: @(signal)};
        NSException *exception = [NSException exceptionWithName:UncaughtExceptionHandlerSignalExceptionName
                                                         reason:[NSString stringWithFormat:@"Signal %d was raised.", signal]
                                                       userInfo:userInfo];

        [handler mp_handleUncaughtException:exception];
    }

    struct sigaction prev_action = handler.prev_signal_handlers[signal];
    if (prev_action.sa_flags & SA_SIGINFO) {
        if (prev_action.sa_sigaction) {
            prev_action.sa_sigaction(signal, info, context);
        }
    } else if (prev_action.sa_handler) {
        prev_action.sa_handler(signal);
    }
}

void MPHandleException(NSException *exception) {
    MixpanelExceptionHandler *handler = [MixpanelExceptionHandler sharedHandler];

    int32_t exceptionCount = OSAtomicIncrement32(&UncaughtExceptionCount);
    if (exceptionCount <= UncaughtExceptionMaximum) {
        [handler mp_handleUncaughtException:exception];
    }

    if (handler.defaultExceptionHandler) {
        handler.defaultExceptionHandler(exception);
    }
}

- (void) mp_handleUncaughtException:(NSException *)exception {
    // Archive the values for each Mixpanel instance
    for (Mixpanel *instance in self.mixpanelInstances) {
        NSMutableDictionary *properties = [[NSMutableDictionary alloc] init];
        [properties setValue:[exception reason] forKey:@"$ae_crashed_reason"];
        [instance track:@"$ae_crashed" properties:properties];
        dispatch_sync(instance.serialQueue, ^{
            [instance archive];
        });
    }
    NSLog(@"Encountered an uncaught exception. All Mixpanel instances were archived.");
}


@end
