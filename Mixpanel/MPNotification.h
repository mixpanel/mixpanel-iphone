#import <Foundation/Foundation.h>

extern NSString *const MPNotificationTypeMini;
extern NSString *const MPNotificationTypeTakeover;

@interface MPNotification : NSObject

@property (nonatomic, readonly) NSUInteger ID;
@property (nonatomic, readonly) NSUInteger messageID;
@property (nonatomic, strong) NSString *type;
@property (nonatomic, strong) NSString *style;
@property (nonatomic, strong) NSURL *imageURL;
@property (nonatomic, strong) NSData *image;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *body;
@property (nonatomic, strong) NSString *callToAction;
@property (nonatomic, strong) NSURL *callToActionURL;

+ (MPNotification *)notificationWithJSONObject:(NSDictionary *)object;
- (instancetype)init __unavailable;

@end
