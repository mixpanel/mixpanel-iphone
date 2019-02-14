#import <Foundation/Foundation.h>
#if !TARGET_OS_WATCH
#import <JavaScriptCore/JavaScriptCore.h>
#endif
#import "MPDisplayTrigger.h"

extern NSString* const PROPERTY_EVAL_FUNC_NAME;
extern NSString* const PROPERTY_FILTERS_JS_URL;

@interface MPNotification : NSObject

@property (nonatomic, readonly) NSDictionary *jsonDescription;
@property (nonatomic, readonly) NSDictionary *extrasDescription;
@property (nonatomic, readonly) NSUInteger ID;
@property (nonatomic, readonly) NSUInteger messageID;
@property (nonatomic, readonly) NSString *type;
@property (nonatomic, copy) NSURL *imageURL;
@property (nonatomic, strong) NSData *image;
@property (nonatomic, readonly) NSString *body;
@property (nonatomic, readonly) NSUInteger bodyColor;
@property (nonatomic, readonly) NSUInteger backgroundColor;
@property (nonatomic, readonly) NSArray *displayTriggers;

- (instancetype)init __unavailable;
- (instancetype)initWithJSONObject:(NSDictionary *)jsonObject;
- (BOOL)hasDisplayTriggers;
- (BOOL)matchesEvent:(NSDictionary *)event;
+ (void)logNotificationError:(NSString *)field withValue:(id)value;
#if !TARGET_OS_WATCH
+ (JSValue*) propertyFilterFunc;
#endif
@end
