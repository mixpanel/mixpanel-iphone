#import <Foundation/Foundation.h>

extern NSString *const MPNotificationTypeMini;
extern NSString *const MPNotificationTypeTakeover;

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

- (instancetype)init __unavailable;
- (instancetype)initWithJSONObject:(NSDictionary *)jsonObject;
+ (void)logNotificationError:(NSString *)field withValue:(id)value;

@end
