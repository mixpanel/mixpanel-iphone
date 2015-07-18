#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, MPPresentationObjectType) {
    // beginning at 1 so that 0 can be utilized for unknown object type if need be someday
    MPPresentationObjectTypeSurvey = 1,
    MPPresentationObjectTypeNotification = 2
};

/*!
 @class
 Mixpanel Presentation Object.
 
 @abstract
 Corresponds to either a notification or survey type.
 
 @discussion
 <b>You should not instantiate this object yourself.</b> An instance of it will
 be provided within the objectArray parameter of the delegate method:
 <pre>
 - (BOOL)mixpanel:(Mixpanel *)mixpanel willShowNotificationOrSurveyFromArray:(NSArray *)objectArray;
 </pre>
 */
@interface MixpanelPresentationObject : NSObject

/*!
 @property
 
 @abstract
 Corresponds to either a notification or survey ID.
 
 @discussion
 Query objectType to determine wether this is a survey or notification ID.
 */
@property (nonatomic, readonly) NSUInteger ID;

/*!
 @property
 
 @abstract
 Denotes wether this object corresponds to a survey or notification.
 
 @discussion
 Use this to determine what type of ID the ID property corresponds to (survey or notification).
 */
@property (nonatomic, readonly) MPPresentationObjectType objectType;

- (instancetype)initWithID:(NSUInteger)ID objectType:(MPPresentationObjectType)objectType;

- (instancetype)init __unavailable;

@end
