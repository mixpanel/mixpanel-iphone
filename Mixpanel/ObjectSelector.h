//
//  ObjectSelector.h
//  HelloMixpanel
//
//  Created by Alex Hofsteede on 5/5/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ObjectSelector : NSObject

-(id) initWithString:(NSString *)string;
-(id)selectFromRoot:(UIView *)root;



@end
