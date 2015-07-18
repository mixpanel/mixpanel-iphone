#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, MPPresentationObjectType) {
    // beginning at 1 so that 0 can be utilized for unknown object type if need be someday
    MPPresentationObjectTypeSurvey = 1,
    MPPresentationObjectTypeNotification = 2
};

@interface MixpanelPresentationObject : NSObject

@property (nonatomic, readonly) NSUInteger ID;
@property (nonatomic, readonly) MPPresentationObjectType objectType;

- (instancetype)initWithID:(NSUInteger)ID objectType:(MPPresentationObjectType)objectType;

- (instancetype)init __unavailable;

@end
