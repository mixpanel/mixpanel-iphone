#import <Foundation/Foundation.h>

@interface MPSurvey : NSObject

@property(nonatomic,readonly) NSUInteger ID;
@property(nonatomic,readonly) NSUInteger collectionID;
@property(nonatomic,readonly,retain) NSArray *questions;
@property(nonatomic,readonly) NSString *name;

+ (MPSurvey *)surveyWithJSONObject:(NSDictionary *)object;

@end
