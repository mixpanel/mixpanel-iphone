#import "MPLogger.h"
#import "MPDisplayTrigger.h"
#import "SelectorEvaluator.h"
#import "Mixpanel.h"

static NSString * const ANY_EVENT = @"$any_event";

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
    NSError *error = nil;
    if ([eventName isEqualToString:ANY_EVENT] || [eventName isEqualToString:_event]) {
        if ([_selector count] > 0) {
            NSNumber *result = [SelectorEvaluator evaluate:_selector properties:event[@"properties"] withError:&error];
            if (error) {
                MPLogError(@"error evaluating selector %@", error);
                return NO;
            }
            return [result boolValue];
        }
        return YES;
    }
    return NO;
}

@end
