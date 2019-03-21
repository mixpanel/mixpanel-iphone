#import <Foundation/Foundation.h>

@interface MPDisplayTrigger : NSObject

@property (nonatomic, readonly) NSDictionary *rawJSON;
@property (nonatomic, readonly) NSString *event;
@property (nonatomic, readonly) NSDictionary *selector;

- (instancetype)init __unavailable;
- (instancetype)initWithJSONObject:(NSDictionary *)jsonObject;
- (BOOL)matchesEvent:(NSDictionary *)event;

@end
