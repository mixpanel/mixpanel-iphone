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
void registerFatalSignals(void);
void unregisterFatalSignals(void);
void prevSignalHandlerCallback(int sig, siginfo_t *info, void *context);

@interface MixpanelExceptionHandler ()

@property (nonatomic) NSUncaughtExceptionHandler *defaultExceptionHandler;
@property (nonatomic, strong) NSHashTable *mixpanelInstances;
@end

@implementation MixpanelExceptionHandler

static NSMutableDictionary *prevSigActions;
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

+ (void)initialize {
    prevSigActions = [NSMutableDictionary dictionary];
}
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
        // Create mutable dictionary for save prev sigaction
        
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
    if (isAlreadyExceptionOccured==0) {
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
    prevSignalHandlerCallback(sig, info, context);

}

void prevSignalHandlerCallback(int sig, siginfo_t *info, void *context) {
  
    NSValue *prevSigaction = [prevSigActions objectForKey:[NSNumber numberWithInt:sig]];
    if(prevSigaction) {
        struct sigaction prev;
        [prevSigaction getValue:&prev];
        prev.sa_sigaction(sig,info,context);
    }
    
}

void registerFatalSignals() {
    
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_flags =  SA_SIGINFO | SA_ONSTACK;
    sa.sa_sigaction = &mp_handleSignal;
    sigemptyset(&sa.sa_mask);
    for (int i=0; i<n_fatal_signals; i++) {
        struct sigaction prev;
        memset(&prev, 0, sizeof(prev));
        sigaction(fatal_signals[i], &sa, &prev);
        
        //Save previous sigaction.
        if(prev.sa_flags & SA_SIGINFO) {
            NSValue *prevSigaction = [NSValue valueWithBytes:&prev objCType:@encode(struct sigaction)];
            [prevSigActions setObject:prevSigaction forKey:[NSNumber numberWithInt:fatal_signals[i]]];
        }
    }
}

void unregisterFatalSignals() {
    
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = SIG_DFL;
    sigemptyset(&sa.sa_mask);
    for (int i=0; i < n_fatal_signals; i++) {
        sigaction(fatal_signals[i], &sa, NULL);
    }
}

@end
