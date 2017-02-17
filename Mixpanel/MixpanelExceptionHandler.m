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

+ (NSArray *)backtrace
{
    void* callstack[128];
    int frames = backtrace(callstack, 128);
    char **strs = backtrace_symbols(callstack, frames);

    int i;
    NSMutableArray *backtrace = [NSMutableArray arrayWithCapacity:frames];
    for (
         i = UncaughtExceptionHandlerSkipAddressCount;
         i < UncaughtExceptionHandlerSkipAddressCount +
         UncaughtExceptionHandlerReportAddressCount;
         i++)
    {
        [backtrace addObject:[NSString stringWithUTF8String:strs[i]]];
    }
    free(strs);
    
    return backtrace;
}


- (instancetype)init {
    self = [super init];
    if (self) {
        // Create a hash table of weak pointers to mixpanel instances
        _mixpanelInstances = [NSHashTable weakObjectsHashTable];
        
        // Save the existing exception handler
        _defaultExceptionHandler = NSGetUncaughtExceptionHandler();
        // Install our handler
        [self setupHandlers];
//        [self performSelector:@selector(setupHandlers) withObject:nil afterDelay:0];
    }
    return self;
}

- (void)setupHandlers {
    NSSetUncaughtExceptionHandler(&HandleException);
    signal(SIGABRT, SignalHandler);
    signal(SIGILL, SignalHandler);
    signal(SIGSEGV, SignalHandler);
    signal(SIGFPE, SignalHandler);
    signal(SIGBUS, SignalHandler);
    signal(SIGPIPE, SignalHandler);
}

- (void)addMixpanelInstance:(Mixpanel *)instance {
    NSParameterAssert(instance != nil);
    
    [self.mixpanelInstances addObject:instance];
}

void SignalHandler(int signal)
{
    int32_t exceptionCount = OSAtomicIncrement32(&UncaughtExceptionCount);
    if (exceptionCount > UncaughtExceptionMaximum)
    {
        return;
    }

    NSMutableDictionary *userInfo =
    [NSMutableDictionary
     dictionaryWithObject:[NSNumber numberWithInt:signal]
     forKey:UncaughtExceptionHandlerSignalKey];

    NSArray *callStack = [MixpanelExceptionHandler backtrace];
    [userInfo
     setObject:callStack
     forKey:UncaughtExceptionHandlerAddressesKey];

    [MixpanelExceptionHandler performSelectorOnMainThread:@selector(mp_handleUncaughtException:)
                              withObject:[NSException
                                          exceptionWithName:UncaughtExceptionHandlerSignalExceptionName
                                          reason:
                                          [NSString stringWithFormat:
                                           NSLocalizedString(@"Signal %d was raised.", nil),
                                           signal]
                                          userInfo:
                                          [NSDictionary
                                           dictionaryWithObject:[NSNumber numberWithInt:signal]
                                           forKey:UncaughtExceptionHandlerSignalKey]] waitUntilDone:YES];
}

void HandleException(NSException *exception)
{
    int32_t exceptionCount = OSAtomicIncrement32(&UncaughtExceptionCount);
    if (exceptionCount > UncaughtExceptionMaximum)
    {
        return;
    }

    NSArray *callStack = [MixpanelExceptionHandler backtrace];
    NSMutableDictionary *userInfo =
    [NSMutableDictionary dictionaryWithDictionary:[exception userInfo]];
    [userInfo
     setObject:callStack
     forKey:UncaughtExceptionHandlerAddressesKey];

    [MixpanelExceptionHandler performSelectorOnMainThread:@selector(mp_handleUncaughtException:)
                              withObject:[NSException
                                          exceptionWithName:[exception name]
                                          reason:[exception reason]
                                          userInfo:userInfo] waitUntilDone:YES];
}


+ (void) mp_handleUncaughtException:(NSException *)exception {
    MixpanelExceptionHandler *handler = [MixpanelExceptionHandler sharedHandler];

    // Archive the values for each Mixpanel instance
    for (Mixpanel *instance in handler.mixpanelInstances) {
        [instance archive];
        [instance track:@"App Crashed" properties:@{@"Reason": [exception reason],
                                                    @"Trace": [[exception userInfo] objectForKey:UncaughtExceptionHandlerAddressesKey]}];
        dispatch_sync(instance.serialQueue, ^{});
    }
    NSLog(@"Encountered an uncaught exception. All Mixpanel instances were archived.");

    NSLog(@"%@", [NSString stringWithFormat:@"Debug details follow:\n%@\n%@",
                  [exception reason],
                  [[exception userInfo] objectForKey:UncaughtExceptionHandlerAddressesKey]]);
    if (handler.defaultExceptionHandler) {
        // Ensure the existing handler gets called once we're finished
        handler.defaultExceptionHandler(exception);
    }
}


@end
