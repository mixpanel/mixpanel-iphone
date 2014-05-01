//
//  MPVariant.m
//  HelloMixpanel
//
//  Created by Alex Hofsteede on 28/4/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//

#import "MPVariant.h"

#import "Shelley.h"

@implementation MPVariant

+ (MPVariant *)variantWithDummyJSONObject {
    NSString *json = @"{\"actions\":[{\"path\": \"UIButton\", \"args\": [\"Test\", 0], \"selector\": \"setTitle:forState:\"}]}";

    NSError *error = nil;
    NSDictionary *object = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
    if (error) {
        NSLog(@"%@ json error: %@, data: %@", self, error, json);
        return nil;
    }
    return [MPVariant variantWithJSONObject:object];
}

+ (MPVariant *)variantWithJSONObject:(NSDictionary *)object {

    NSArray *actions = [object objectForKey:@"actions"];
    if (![actions isKindOfClass:[NSArray class]]) {
        NSLog(@"Variant requires an array of actions");
        return nil;
    }

    return [[MPVariant alloc] initWithActions:actions];
}

+ (NSArray *)getViewsOnPath:(NSString *)path fromRoot:(UIView *)root
{
    Shelley *shelley = [[Shelley alloc] initWithSelectorString:path];
    return [shelley selectFrom:root];
}


+ (void)setValue:(id)value forKey:(NSString *)key onPath:(NSString *)path fromRoot:(UIView *)root
{
    NSArray *views = [self getViewsOnPath:path fromRoot:root];
    if ([views count] > 0) {
        for (NSObject *o in views) {
            [o setValue:value forKey:key];
        }
    } else {
        NSLog(@"No objects matching pattern");
    }
}

+ (void)executeSelector:(SEL)selector withArgs:(NSArray *)args onPath:(NSString *)path fromRoot:(UIView *)root
{
    NSArray *views = [self getViewsOnPath:path fromRoot:root];
    if ([views count] > 0) {
        for (NSObject *o in views) {
            NSMethodSignature *signature = [o methodSignatureForSelector:selector];
            if (signature != nil) {
                NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
                uint requiredArgs = [signature numberOfArguments] - 2;
                if ([args count] >= requiredArgs) {
                    [invocation setSelector:selector];
                    for (uint i = 0; i < requiredArgs; i++) {
                        NSObject *arg = [args objectAtIndex:i];
                        #pragma message("TODO: Deserialize arguments, eg CGColorRef from r,g,b values")
                        // convert NSValues into their base types
                        if( [arg isKindOfClass:[NSValue class]] ) {
                            void *buf = malloc(sizeof([(NSValue *)arg objCType]));
                            [(NSValue *)arg getValue:buf];
                            [invocation setArgument:(void *)buf atIndex:(int)(i+2)];
                        } else {
                            [invocation setArgument:(void *)&arg atIndex:(int)(i+2)];
                        }
                    }
                    [invocation invokeWithTarget:o];
                } else {
                    NSLog(@"Not enough args");
                }
            } else {
                NSLog(@"No selector");
            }
        }
    } else {
        NSLog(@"No objects matching pattern");
    }
}


- (id) initWithActions:(NSArray *)actions
{
    if(self = [super init]) {
        self.actions = actions;
    }
    return self;
}

- (void)execute {
    for (NSDictionary *action in self.actions) {
        [[self class] executeSelector:NSSelectorFromString([action objectForKey:@"selector"])
                         withArgs:[action objectForKey:@"args"]
                           onPath:[action objectForKey:@"path"]
                         fromRoot:[[[[UIApplication sharedApplication] keyWindow] rootViewController] view]];
    }
}

@end
