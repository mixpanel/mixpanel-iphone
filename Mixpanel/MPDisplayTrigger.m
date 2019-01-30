#import "MPLogger.h"
#import "MPDisplayTrigger.h"
#import "Mixpanel.h"

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
        
        _jsonObject = object;
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
    if ([eventName caseInsensitiveCompare:@""] == NSOrderedSame ||
        [eventName caseInsensitiveCompare:ANY_EVENT] == NSOrderedSame ||
        [eventName caseInsensitiveCompare:[self event]] == NSOrderedSame) {
            return YES;
    }
    
    return NO;
}

@end
