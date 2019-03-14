#import <Foundation/Foundation.h>
#import "MPDisplayTrigger.h"

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

@end
