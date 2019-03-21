#import <Foundation/Foundation.h>

@interface MPBoolean : NSObject

@property (nonatomic, readonly) BOOL value;

- (instancetype)init:(BOOL)value;

@end

@interface SelectorEvaluator : NSObject

+ (NSDate*)currentDate;
+ (NSDateFormatter*)dateFormatter;

+ (double)toNumber:(id)value
         withError:(NSError **)error;

+ (BOOL)toBoolean:(id)value;

+ (id)evaluateNode:(NSDictionary *)node
        properties:(NSDictionary *)properties
         withError:(NSError **)error;

+ (NSDate *)evaluateWindow:(NSDictionary *)value
                 withError:(NSError **)error;

+ (id)evaluateOperand:(NSDictionary *)node
           properties:(NSDictionary *)properties
            withError:(NSError **)error;

+ (id)evaluateOperator:(NSDictionary *)node
            properties:(NSDictionary *)properties
             withError:(NSError **)error;

+ (NSNumber *)evaluateNumber:(NSDictionary *)node
                  properties:(NSDictionary *)properties
                   withError:(NSError **)error;

+ (MPBoolean *)evaluateBoolean:(NSDictionary *)node
                    properties:(NSDictionary *)properties
                     withError:(NSError **)error;

+ (NSDate *)evaluateDateTime:(NSDictionary *)node
                  properties:(NSDictionary *)properties
                   withError:(NSError **)error;

+ (NSArray *)evaluateList:(NSDictionary *)node
               properties:(NSDictionary *)properties
                withError:(NSError **)error;

+ (NSString *)evaluateString:(NSDictionary *)node
                  properties:(NSDictionary *)properties
                   withError:(NSError **)error;

+ (MPBoolean *)evaluateAnd:(NSDictionary *)node
                properties:(NSDictionary *)properties
                 withError:(NSError **)error;

+ (MPBoolean *)evaluateOr:(NSDictionary *)node
               properties:(NSDictionary *)properties
                withError:(NSError **)error;

+ (MPBoolean *)evaluateIn:(NSDictionary *)node
               properties:(NSDictionary *)properties
                withError:(NSError **)error;

+ (id)evaluatePlus:(NSDictionary *)node
        properties:(NSDictionary *)properties
         withError:(NSError **)error;

+ (NSNumber *)evaluateArithmetic:(NSDictionary *)node
                      properties:(NSDictionary *)properties
                       withError:(NSError **)error;

+ (MPBoolean *)evaluateEquality:(NSDictionary *)node
                     properties:(NSDictionary *)properties
                      withError:(NSError **)error;

+ (MPBoolean *)evaluateComparison:(NSDictionary *)node
                       properties:(NSDictionary *)properties
                        withError:(NSError **)error;

+ (MPBoolean *)evaluateDefined:(NSDictionary *)node
                    properties:(NSDictionary *)properties
                     withError:(NSError **)error;

+ (MPBoolean *)evaluateNot:(NSDictionary *)node
                properties:(NSDictionary *)properties
                 withError:(NSError **)error;

+ (id)evaluate:(NSDictionary *)selector
    properties:(NSDictionary *)properties
     withError:(NSError **)error;

@end
