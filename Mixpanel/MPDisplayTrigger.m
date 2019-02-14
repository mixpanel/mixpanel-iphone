#import "MPLogger.h"
#import "MPDisplayTrigger.h"
#import "Mixpanel.h"
#import "Mixpanel/Mixpanel-Swift.h"

NSString * const ANY_EVENT = @"$any_event";

@implementation MPDisplayTrigger

- (instancetype)initWithJSONObject:(NSDictionary *)object {
    if (self = [super init]) {
        if (object == nil) {
            MPLogError(@"display trigger json object should not be nil");
            return nil;
        }
        
        NSString *event = object[@"event"];
        if ([event isEqual:[NSNull null]]) {
            event = @"";
        }
        
        _rawJSON = object;
        _event = event;
        _selector = object[@"selector"];
    }
    
    return self;
}

- (BOOL)matchesEvent:(NSDictionary *)event {
    if (event == nil) {
        return NO;
    }
    
    NSString *eventName = event[@"event"];
    if ([eventName compare:ANY_EVENT] == NSOrderedSame ||
        [eventName compare:[self event]] == NSOrderedSame) {
        if ([_selector count] > 0) {
            return [SelectorEvaluator evaluateWithSelector:_selector properties:event[@"properties"]];
        }
        return YES;
    }
    
    return NO;
}

@end
