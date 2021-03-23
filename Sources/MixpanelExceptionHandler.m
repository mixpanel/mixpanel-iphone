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
#include <stdatomic.h>


static NSString * const UncaughtExceptionHandlerSignalExceptionName = @"UncaughtExceptionHandlerSignalExceptionName";
static NSString * const UncaughtExceptionHandlerSignalKey = @"UncaughtExceptionHandlerSignalKey";

static volatile atomic_int_fast32_t UncaughtExceptionCount = 0;
static const atomic_int_fast32_t UncaughtExceptionMaximum = 10;

@interface MixpanelExceptionHandler ()

@property (nonatomic) NSUncaughtExceptionHandler *defaultExceptionHandler;
@property (nonatomic, unsafe_unretained) struct sigaction *prev_signal_handlers;
@property (nonatomic, strong) NSMutableArray *mixpanelInstances;

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
        _mixpanelInstances = [NSMutableArray new];
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
    int signals[] = {SIGABRT, SIGILL, SIGSEGV, SIGFPE, SIGBUS};
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wsign-compare"
    for (int i = 0; i < sizeof(signals) / sizeof(int); i++) {
        struct sigaction prev_action;
        int err = sigaction(signals[i], &action, &prev_action);
        if (err == 0) {
            memcpy(_prev_signal_handlers + signals[i], &prev_action, sizeof(prev_action));
        } else {
            MPLogWarning(@"Errored while trying to set up sigaction for signal %d", signals[i]);
        }
    }
#pragma clang diagnostic pop
}

- (void)addMixpanelInstance:(Mixpanel *)instance {
    NSParameterAssert(instance != nil);
    
    [self.mixpanelInstances addObject:instance];
}

void MPSignalHandler(int signalNumber, struct __siginfo *info, void *context) {
    MixpanelExceptionHandler *handler = [MixpanelExceptionHandler sharedHandler];

    atomic_int_fast32_t exceptionCount = atomic_fetch_add_explicit(&UncaughtExceptionCount, 1, memory_order_relaxed);
    
    if (exceptionCount <= UncaughtExceptionMaximum) {
        NSDictionary *userInfo = @{UncaughtExceptionHandlerSignalKey: @(signalNumber)};
        NSException *exception = [NSException exceptionWithName:UncaughtExceptionHandlerSignalExceptionName
                                                         reason:[NSString stringWithFormat:@"Signal %d was raised.", signalNumber]
                                                       userInfo:userInfo];

        [handler mp_handleUncaughtException:exception];
    }

    struct sigaction prev_action = handler.prev_signal_handlers[signalNumber];
    // Since there is no way to pass through to the default handler, re-raise the signal as our best efforts
    if (prev_action.sa_handler == SIG_DFL) {
        signal(signalNumber, SIG_DFL);
        raise(signalNumber);
        return;
    }
    if (prev_action.sa_flags & SA_SIGINFO) {
        if (prev_action.sa_sigaction) {
            prev_action.sa_sigaction(signalNumber, info, context);
        }
    } else if (prev_action.sa_handler) {
        prev_action.sa_handler(signalNumber);
    }
}

void MPHandleException(NSException *exception) {
    MixpanelExceptionHandler *handler = [MixpanelExceptionHandler sharedHandler];

    atomic_int_fast32_t exceptionCount = atomic_fetch_add_explicit(&UncaughtExceptionCount, 1, memory_order_relaxed);
    if (exceptionCount <= UncaughtExceptionMaximum) {
        [handler mp_handleUncaughtException:exception];
    }

    if (handler.defaultExceptionHandler) {
        handler.defaultExceptionHandler(exception);
    }
}

- (void) mp_handleUncaughtException:(NSException *)exception {
    // Archive the values for each Mixpanel instance
    [self.mixpanelInstances enumerateObjectsUsingBlock:^(Mixpanel *instance, NSUInteger idx, BOOL * _Nonnull stop) {
        NSMutableDictionary *properties = [[NSMutableDictionary alloc] init];
        [properties setValue:[exception reason] forKey:@"$ae_crashed_reason"];
        [instance track:@"$ae_crashed" properties:properties];
    }];
    MPLogWarning(@"Encountered an uncaught exception. All Mixpanel instances were archived.");
}


@end
