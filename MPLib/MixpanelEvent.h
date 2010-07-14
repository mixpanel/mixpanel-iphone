//
//  MixpanelEvent.h
//  MPLib
//
//  Created by Elfred Pagan on 6/18/10.
//  Copyright 2010 elfredpagan.com. All rights reserved.
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
