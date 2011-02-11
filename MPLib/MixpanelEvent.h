//
//  MixpanelEvent.h
//  MPLib
//
//

#import <Foundation/Foundation.h>
#import "MixpanelAPI.h"
@interface MixpanelEvent : NSObject<NSCoding> {
	NSString *name;
	MPLibEventType eventType;
	NSMutableDictionary *properties;
	NSDate *timestamp;
}
- (id) initWithName:(NSString*) name type:(MPLibEventType) type properties:(NSDictionary*) properties;
- (NSDictionary*) dictionaryValue;
@end
