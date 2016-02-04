//
//  MixpanelExceptionHandler.m
//  HelloMixpanel
//
//  Created by Sam Green on 7/28/15.
//  Copyright (c) 2015 Mixpanel. All rights reserved.
//

#import "MixpanelExceptionHandler.h"
#import "Mixpanel.h"
#import "MPLogger.h"

#include <libkern/OSAtomic.h>

@interface MixpanelExceptionHandler ()

@property (nonatomic) NSUncaughtExceptionHandler *defaultExceptionHandler;
@property (nonatomic, strong) NSHashTable *mixpanelInstances;

@end

@implementation MixpanelExceptionHandler

static uint32_t volatile isAlreadyExceptionOccured =0;
static int fatal_signals[] =
{
    SIGILL  ,   /* illegal instruction (not reset when caught) */
    SIGTRAP ,   /* trace trap (not reset when caught) */
    SIGABRT ,   /* abort() */
    SIGFPE  ,   /* floating point exception */
    SIGBUS  ,   /* bus error */
    SIGSEGV ,   /* segmentation violation */
    SIGSYS  ,   /* bad argument to system call */
};
static int n_fatal_signals = (sizeof(fatal_signals) / sizeof(fatal_signals[0]));

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
        // Save the existing exception handler
        _defaultExceptionHandler = NSGetUncaughtExceptionHandler();
        // Install our handler
        NSSetUncaughtExceptionHandler(&mp_handleUncaughtException);
        // Install signal Handler
        registerFatalSignals();
    }
    return self;
}

- (void)addMixpanelInstance:(Mixpanel *)instance {
    NSParameterAssert(instance != nil);
    [self.mixpanelInstances addObject:instance];
}

static void mp_handleUncaughtException(NSException *exception) {
    MixpanelExceptionHandler *handler = [MixpanelExceptionHandler sharedHandler];
    NSLog(@"!!!!!!");
    if(isAlreadyExceptionOccured==0) {
        OSAtomicOr32Barrier(1, &isAlreadyExceptionOccured);
        // Archive the values for each Mixpanel instance
        for (Mixpanel *instance in handler.mixpanelInstances) {
            // Since we're storing the instances in a weak table, we need to ensure the pointer hasn't become nil
            if (instance) {
                [instance archive];
            }
        }
        
        MixpanelError(@"Encountered an uncaught exception. All Mixpanel instances were archived.");
    }
    if (handler.defaultExceptionHandler) {
        // Ensure the existing handler gets called once we're finished
        handler.defaultExceptionHandler(exception);
    }
}

static void mp_handleSignal(int sig, siginfo_t *info, void *context) {
    unregisterFatalSignals();
    MixpanelError(@"We received a signal: %d", sig);
    NSLog(@"??????");

    NSException* exception = [NSException
                              exceptionWithName:@"UncaughtException"
                              reason:
                              [NSString stringWithFormat:
                               NSLocalizedString(@"Signal %d was raised.", nil),
                               sig]
                              userInfo:
                              [NSDictionary
                               dictionaryWithObject:[NSNumber numberWithInt:sig]
                               forKey:@"UncaughtExceptionSignalKey"]];
    
    mp_handleUncaughtException(exception);
}

static void registerFatalSignals() {
    struct sigaction sa;
    /* Configure action */
    memset(&sa, 0, sizeof(sa));
    sa.sa_flags =  SA_SIGINFO | SA_ONSTACK;
    sa.sa_sigaction = &mp_handleSignal;
    sigemptyset(&sa.sa_mask);
    /* Set new sigaction */
    for (int i =0 ;i<n_fatal_signals; i++) {
        if (sigaction(fatal_signals[i], &sa, NULL) != 0) {
            //            int err = errno;
            //            NSAssert(0,"Signal registration for %s failed: %s", strsignal(fatal_signals[i]), strerror(err));
        }
    }
    
}

static void unregisterFatalSignals() {
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = SIG_DFL;
    sigemptyset(&sa.sa_mask);
    for (int i = 0; i < n_fatal_signals; i++) {
        sigaction(fatal_signals[i], &sa, NULL);
    }
}

@end
