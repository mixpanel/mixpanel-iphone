#import "SelectorEvaluator.h"

static NSString *const errDomain = @"SelectorEvaluatorError";
static NSInteger const errCode = -1;

static NSString *const OPERATOR_KEY = @"operator";
static NSString *const CHILDREN_KEY = @"children";
static NSString *const PROPERTY_KEY = @"property";
static NSString *const VALUE_KEY = @"value";
static NSString *const EVENT_KEY = @"event";
static NSString *const LITERAL_KEY = @"literal";
static NSString *const WINDOW_KEY = @"window";
static NSString *const UNIT_KEY = @"unit";
static NSString *const HOUR_KEY = @"hour";
static NSString *const DAY_KEY = @"day";
static NSString *const WEEK_KEY = @"week";
static NSString *const MONTH_KEY = @"month";
// Typecast operators
static NSString *const BOOLEAN_OPERATOR = @"boolean";
static NSString *const DATETIME_OPERATOR = @"datetime";
static NSString *const LIST_OPERATOR = @"list";
static NSString *const NUMBER_OPERATOR = @"number";
static NSString *const STRING_OPERATOR = @"string";
// Binary operators
static NSString *const AND_OPERATOR = @"and";
static NSString *const OR_OPERATOR = @"or";
static NSString *const IN_OPERATOR = @"in";
static NSString *const NOT_IN_OPERATOR = @"not in";
static NSString *const PLUS_OPERATOR = @"+";
static NSString *const MINUS_OPERATOR = @"-";
static NSString *const MUL_OPERATOR = @"*";
static NSString *const DIV_OPERATOR = @"/";
static NSString *const MOD_OPERATOR = @"%";
static NSString *const EQUALS_OPERATOR = @"==";
static NSString *const NOT_EQUALS_OPERATOR = @"!=";
static NSString *const GREATER_THAN_OPERATOR = @">";
static NSString *const GREATER_THAN_EQUAL_OPERATOR = @">=";
static NSString *const LESS_THAN_OPERATOR = @"<";
static NSString *const LESS_THAN_EQUAL_OPERATOR = @"<=";
// Unary operators
static NSString *const NOT_OPERATOR = @"not";
static NSString *const DEFINED_OPERATOR = @"defined";
static NSString *const NOT_DEFINED_OPERATOR = @"not defined";
// Special words
static NSString *const NOW_LITERAL = @"now";

static NSInteger const kLEFT = 0;
static NSInteger const kRIGHT = 1;

@implementation MPBoolean: NSObject

- (instancetype)init:(BOOL)value
{
    self = [super init];
    if (self) {
        _value = value;
    }

    return self;
}

- (BOOL)isEqualToMPBoolean:(MPBoolean *)other {
    return [self value] == [other value];
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    
    if (![object isKindOfClass:[MPBoolean class]]) {
        return NO;
    }

    return [self isEqualToMPBoolean:object];
}

@end

@implementation SelectorEvaluator

// This function exists so that unit tests can inject dates for test cases
+ (NSDate *)currentDate {
    return [NSDate date];
}

+ (NSDateFormatter *)dateFormatter {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss"];
        [formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
    });

    return formatter;
}

+ (NSError *)error:(NSString *)errDesc {
    NSDictionary *info = @{
                           NSLocalizedDescriptionKey: NSLocalizedString(errDesc, nil),
                           };

    return [[NSError alloc] initWithDomain:errDomain code:errCode userInfo:info];
}

+ (double)toNumber:(id)value withError:(NSError *__autoreleasing *)error {
    if ([value isKindOfClass:[NSNumber class]]) {
        return [value doubleValue];
    }
    if ([value isKindOfClass:[MPBoolean class]]) {
        return [(MPBoolean *)value value];
    }
    if ([value isKindOfClass:[NSDate class]]) {
        double time = [(NSDate *)value timeIntervalSince1970];
        if (time <= 0) {
            *error = [self error:@"invalid value for date"];
            return 0.0;
        }
        return time;
    }
    if ([value isKindOfClass:[NSString class]]) {
        return [(NSString *)value doubleValue];
    }
    *error = [self error:@"invalid type"];

    return 0.0;
}

+ (BOOL)toBoolean:(id)value {
    if ([value isKindOfClass:[NSNumber class]]) {
        return [value boolValue];
    }
    if ([value isKindOfClass:[MPBoolean class]]) {
        return [(MPBoolean *)value value];
    }
    if ([value isKindOfClass:[NSDate class]]) {
        return [(NSDate *)value timeIntervalSince1970] > 0 ? YES: NO;
    }
    if ([value isKindOfClass:[NSString class]]) {
        return [(NSString *)value length] > 0 ? YES: NO;
    }
    if ([value isKindOfClass:[NSArray class]]) {
        return [(NSArray *)value count] > 0 ? YES: NO;
    }
    if ([value isKindOfClass:[NSDictionary class]]) {
        return [(NSArray *)value count] > 0 ? YES: NO;
    }

    return NO;
}

+ (NSNumber *)evaluateNumber:(NSDictionary *)node properties:(NSDictionary *)properties withError:(NSError *__autoreleasing *)error {
    if (![node objectForKey:OPERATOR_KEY] || ![node[OPERATOR_KEY] isEqualToString:NUMBER_OPERATOR]) {
        if (error) {
            *error = [self error:@"invalid operator: number"];
        }
        return nil;
    }
    if (![node objectForKey:CHILDREN_KEY]  || !([(NSArray *)node[CHILDREN_KEY] isKindOfClass:[NSArray class]] &&
                                                ([(NSArray *)node[CHILDREN_KEY] count] == 1))) {
        if (error) {
            *error = [self error:@"invalid operator: number"];
        }
        return nil;
    }
    id child = [self evaluateNode:node[CHILDREN_KEY][kLEFT] properties:properties withError:error];
    if (error && *error) {
        return nil;
    }

    return [[NSNumber alloc] initWithDouble:[self toNumber:child withError:error]];
}

+ (MPBoolean *)evaluateBoolean:(NSDictionary *)node properties:(NSDictionary *)properties withError:(NSError *__autoreleasing *)error {
    if (![node objectForKey:OPERATOR_KEY] || ![node[OPERATOR_KEY] isEqualToString:BOOLEAN_OPERATOR]) {
        if (error) {
            *error = [self error:@"invalid operator: boolean"];
        }
        return nil;
    }
    if (![node objectForKey:CHILDREN_KEY]  || !([(NSArray *)node[CHILDREN_KEY] isKindOfClass:[NSArray class]] &&
                                                ([(NSArray *)node[CHILDREN_KEY] count] == 1))) {
        if (error) {
            *error = [self error:@"invalid operator: boolean"];
        }
        return nil;
    }
    id child = [self evaluateNode:node[CHILDREN_KEY][kLEFT] properties:properties withError:error];
    if (error && *error) {
        return nil;
    }

    return [[MPBoolean alloc] init:[self toBoolean:child]];
}

+ (NSDate *)evaluateDateTime:(NSDictionary *)node properties:(NSDictionary *)properties withError:(NSError *__autoreleasing *)error {
    if (![node objectForKey:OPERATOR_KEY] || ![node[OPERATOR_KEY] isEqualToString:DATETIME_OPERATOR]) {
        if (error) {
            *error = [self error:@"invalid operator: datetime"];
        }
        return nil;
    }
    if (![node objectForKey:CHILDREN_KEY]  || !([(NSArray *)node[CHILDREN_KEY] isKindOfClass:[NSArray class]] &&
                                                ([(NSArray *)node[CHILDREN_KEY] count] == 1))) {
        if (error) {
            *error = [self error:@"invalid operator: datetime"];
        }
        return nil;
    }
    NSObject *child = [self evaluateNode:node[CHILDREN_KEY][kLEFT] properties:properties withError:error];
    if (error && *error) {
        return nil;
    }
    if ([child isKindOfClass:[MPBoolean class]]) {
        return nil;
    }
    if ([child isKindOfClass:[NSNumber class]]) {
        return [NSDate dateWithTimeIntervalSince1970:[(NSNumber *)child integerValue]];
    }
    if ([child isKindOfClass:[NSString class]]) {
        NSDateFormatter *formatter = [self dateFormatter];
        return [formatter dateFromString:(NSString *)child];
    }
    if ([child isKindOfClass:[NSDate class]]) {
        return (NSDate *)child;
    }

    return nil;
}

+ (NSArray *)evaluateList:(NSDictionary *)node properties:(NSDictionary *)properties withError:(NSError *__autoreleasing *)error {
    if (![node objectForKey:OPERATOR_KEY] || ![node[OPERATOR_KEY] isEqualToString:LIST_OPERATOR]) {
        if (error) {
            *error = [self error:@"invalid operator: list"];
        }
        return nil;
    }
    if (![node objectForKey:CHILDREN_KEY]  || !([(NSArray *)node[CHILDREN_KEY] isKindOfClass:[NSArray class]] &&
                                                ([(NSArray *)node[CHILDREN_KEY] count] == 1))) {
        if (error) {
            *error = [self error:@"invalid operator: list"];
        }
        return nil;
    }
    NSArray *result = [self evaluateNode:node[CHILDREN_KEY][kLEFT] properties:properties withError:error];
    if ([result isKindOfClass:[NSArray class]]) {
        return result;
    }

    return nil;
}

+ (NSString *)toJSONString:(NSObject *) obj withError:(NSError *__autoreleasing *)error {
    NSData *data = [NSJSONSerialization dataWithJSONObject:obj options:0 error:error];

    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

+ (NSString *)evaluateString:(NSDictionary *)node properties:(NSDictionary *)properties withError:(NSError *__autoreleasing *)error {
    if (![node objectForKey:OPERATOR_KEY] || ![node[OPERATOR_KEY] isEqualToString:STRING_OPERATOR]) {
        if (error) {
            *error = [self error:@"invalid operator: string"];
        }
        return nil;
    }
    if (![node objectForKey:CHILDREN_KEY]  || !([(NSArray *)node[CHILDREN_KEY] isKindOfClass:[NSArray class]] &&
                                                ([(NSArray *)node[CHILDREN_KEY] count] == 1))) {
        if (error) {
            *error = [self error:@"invalid operator: string"];
        }
        return nil;
    }
    NSObject *child = [self evaluateNode:node[CHILDREN_KEY][kLEFT] properties:properties withError:error];
    if (error && *error) {
        return nil;
    }
    
    if ([child isKindOfClass:[NSString class]]) {
        return (NSString *)child;
    }
    if ([child isKindOfClass:[MPBoolean class]]) {
        return [NSString stringWithFormat:@"%@", [(MPBoolean *)child value] ? @"YES" : @"NO"];
    }
    if ([child isKindOfClass:[NSDate class]]) {
        return [[self dateFormatter] stringFromDate:(NSDate *)child];
    }
    if ([child isKindOfClass:[NSNumber class]]) {
        return [(NSNumber *)child stringValue];
    }
    if ([child isKindOfClass:[NSArray class]] || [child isKindOfClass:[NSDictionary class]]) {
        return [self toJSONString:child withError:error];
    }

    return nil;
}

+ (MPBoolean *)evaluateAnd:(NSDictionary *)node properties:(NSDictionary *)properties withError:(NSError *__autoreleasing *)error {
    if (![node objectForKey:OPERATOR_KEY] || ![node[OPERATOR_KEY] isEqualToString:AND_OPERATOR]) {
        if (error) {
            *error = [self error:@"invalid operator: and"];
        }
        return nil;
    }
    if (![node objectForKey:CHILDREN_KEY]  || !([(NSArray *)node[CHILDREN_KEY] isKindOfClass:[NSArray class]] &&
                                                ([(NSArray *)node[CHILDREN_KEY] count] == 2))) {
        if (error) {
            *error = [self error:@"invalid operator: and"];
        }
        return nil;
    }
    
    BOOL left = [self toBoolean:[self evaluateNode:node[CHILDREN_KEY][kLEFT] properties:properties withError:error]];
    BOOL right = [self toBoolean:[self evaluateNode:node[CHILDREN_KEY][kRIGHT] properties:properties withError:error]];

    return [[MPBoolean alloc] init:left && right];
}

+ (MPBoolean *)evaluateOr:(NSDictionary *)node properties:(NSDictionary *)properties withError:(NSError *__autoreleasing *)error {
    if (![node objectForKey:OPERATOR_KEY] || ![node[OPERATOR_KEY] isEqualToString:OR_OPERATOR]) {
        if (error) {
            *error = [self error:@"invalid operator: or"];
        }
        return nil;
    }
    if (![node objectForKey:CHILDREN_KEY]  || !([(NSArray *)node[CHILDREN_KEY] isKindOfClass:[NSArray class]] &&
                                                ([(NSArray *)node[CHILDREN_KEY] count] == 2))) {
        if (error) {
            *error = [self error:@"invalid operator: or"];
        }
        return nil;
    }
    
    BOOL left = [self toBoolean:[self evaluateNode:node[CHILDREN_KEY][kLEFT] properties:properties withError:error]];
    BOOL right = [self toBoolean:[self evaluateNode:node[CHILDREN_KEY][kRIGHT] properties:properties withError:error]];

    return [[MPBoolean alloc] init:left || right];
}

+ (MPBoolean *)evaluateIn:(NSDictionary *)node properties:(NSDictionary *)properties withError:(NSError *__autoreleasing *)error {
    NSArray *supportedOperators = @[IN_OPERATOR, NOT_IN_OPERATOR];
    if (![node objectForKey:OPERATOR_KEY] || !([supportedOperators containsObject:node[OPERATOR_KEY]])) {
        if (error) {
            *error = [self error:@"invalid operator: in"];
        }
        return nil;
    }
    if (![node objectForKey:CHILDREN_KEY]  || !([(NSArray *)node[CHILDREN_KEY] isKindOfClass:[NSArray class]] &&
                                                ([(NSArray *)node[CHILDREN_KEY] count] == 2))) {
        if (error) {
            *error = [self error:@"invalid operator: in"];
        }
        return nil;
    }
    
    id l = [self evaluateNode:node[CHILDREN_KEY][kLEFT] properties:properties withError:error];
    if (error && *error) {
        return nil;
    }
    id r = [self evaluateNode:node[CHILDREN_KEY][kRIGHT] properties:properties withError:error];
    if (error && *error) {
        return nil;
    }
    BOOL b = NO;
    if ([(NSString *)l isKindOfClass:[NSString class]] && [(NSString *)r isKindOfClass:[NSString class]]) {
        b = [(NSString *)r containsString:(NSString *)l];
    } else if ([(NSArray *)r isKindOfClass:[NSArray class]]) {
        b = [(NSArray *)r containsObject:l];
    }
    
    if ([node[OPERATOR_KEY] isEqualToString:NOT_IN_OPERATOR]) {
        b = !b;
    }

    return [[MPBoolean alloc] init:b];
}

+ (id)evaluatePlus:(NSDictionary *)node properties:(NSDictionary *)properties withError:(NSError *__autoreleasing *)error {
    if (![node objectForKey:OPERATOR_KEY] || !([node[OPERATOR_KEY] isEqualToString:PLUS_OPERATOR])) {
        if (error) {
            *error = [self error:@"invalid operator: +"];
        }
        return nil;
    }
    if (![node objectForKey:CHILDREN_KEY]  || !([(NSArray *)node[CHILDREN_KEY] isKindOfClass:[NSArray class]] &&
                                                ([(NSArray *)node[CHILDREN_KEY] count] == 2))) {
        if (error) {
            *error = [self error:@"invalid operator: +"];
        }
        return nil;
    }
    
    id l = [self evaluateNode:node[CHILDREN_KEY][kLEFT] properties:properties withError:error];
    if (error && *error) {
        return nil;
    }
    id r = [self evaluateNode:node[CHILDREN_KEY][kRIGHT] properties:properties withError:error];
    if (error && *error) {
        return nil;
    }
    
    if ([(NSString *)l isKindOfClass:[NSString class]] && [(NSString *)r isKindOfClass:[NSString class]]) {
        return [NSString stringWithFormat:@"%@%@", (NSString *)l, (NSString *)r];
    }
    if ([(NSNumber *)l isKindOfClass:[NSNumber class]] && [(NSNumber *)r isKindOfClass:[NSNumber class]]) {
        return [NSNumber numberWithDouble:[(NSNumber *)l doubleValue] + [(NSNumber *)r doubleValue]];
    }

    return nil;
}

+ (NSNumber *)evaluateArithmetic:(NSDictionary *)node properties:(NSDictionary *)properties withError:(NSError *__autoreleasing *)error {
    NSArray *supportedOperators = @[MINUS_OPERATOR, DIV_OPERATOR, MUL_OPERATOR, MOD_OPERATOR];
    if (![node objectForKey:OPERATOR_KEY] || !([supportedOperators containsObject:node[OPERATOR_KEY]])) {
        if (error) {
            *error = [self error:@"invalid arithmetic operator"];
        }
        return nil;
    }
    if (![node objectForKey:CHILDREN_KEY]  || !([(NSArray *)node[CHILDREN_KEY] isKindOfClass:[NSArray class]] &&
                                                ([(NSArray *)node[CHILDREN_KEY] count] == 2))) {
        if (error) {
            *error = [self error:@"invalid arithmetic operator"];
        }
        return nil;
    }
    
    id l = [self evaluateNode:node[CHILDREN_KEY][kLEFT] properties:properties withError:error];
    if (error && *error) {
        return nil;
    }
    id r = [self evaluateNode:node[CHILDREN_KEY][kRIGHT] properties:properties withError:error];
    if (error && *error) {
        return nil;
    }
    
    if ([(NSNumber *)l isKindOfClass:[NSNumber class]] && [(NSNumber *)r isKindOfClass:[NSNumber class]]) {
        double ld = [(NSNumber *)l doubleValue];
        double rd = [(NSNumber *)r doubleValue];
        NSString *op = node[OPERATOR_KEY];
        if ([op isEqualToString:MINUS_OPERATOR]) {
            return [NSNumber numberWithDouble:ld - rd];
        }
        if ([op isEqualToString:MUL_OPERATOR]) {
            return [NSNumber numberWithDouble:ld * rd];
        }
        if ([op isEqualToString:DIV_OPERATOR]) {
            return (NSInteger)rd != 0 ? [NSNumber numberWithDouble:ld / rd] : nil;
        }
        if ([op isEqualToString:MOD_OPERATOR]) {
            if ((NSInteger)rd == 0) {
                return nil;
            }
            if ((NSInteger)ld == 0) {
                return [NSNumber numberWithDouble:0];
            }
            if ((ld < 0 && rd > 0) || (ld > 0 && rd < 0)) {
                return [NSNumber numberWithDouble:-(floor(ld / rd) * rd - ld)];
            }
            return [NSNumber numberWithDouble:fmod(ld, rd)];
        }
    }

    return nil;
}

+ (MPBoolean *)evaluateEquality:(NSDictionary *)node properties:(NSDictionary *)properties withError:(NSError *__autoreleasing *)error {
    NSArray *supportedOperators = @[EQUALS_OPERATOR, NOT_EQUALS_OPERATOR];
    if (![node objectForKey:OPERATOR_KEY] || !([supportedOperators containsObject:node[OPERATOR_KEY]])) {
        if (error) {
            *error = [self error:@"invalid (not) equality operator"];
        }
        return nil;
    }
    if (![node objectForKey:CHILDREN_KEY]  || !([(NSArray *)node[CHILDREN_KEY] isKindOfClass:[NSArray class]] &&
                                                ([(NSArray *)node[CHILDREN_KEY] count] == 2))) {
        if (error) {
            *error = [self error:@"invalid (not) equality operator"];
        }
        return nil;
    }
    
    id l = [self evaluateNode:node[CHILDREN_KEY][kLEFT] properties:properties withError:error];
    if (error && *error) {
        return nil;
    }
    id r = [self evaluateNode:node[CHILDREN_KEY][kRIGHT] properties:properties withError:error];
    if (error && *error) {
        return nil;
    }
    
    BOOL b = NO;
    if (l == nil && r == nil) {
        b = YES;
    } else if ([(MPBoolean *)l isKindOfClass:[MPBoolean class]]) {
        // left operand should be from the evaluation of a non literal type
        b = [(MPBoolean *)l value] == [self toBoolean:r];
    } else {
        b = [l isEqual:r];
    }
    
    if ([node[OPERATOR_KEY] isEqualToString:NOT_EQUALS_OPERATOR]) {
        b = !b;
    }

    return [[MPBoolean alloc] init:b];
}

+ (BOOL)compareDoubles:(double) l r:(double) r op:(NSString*) op {
    if ([op isEqualToString:GREATER_THAN_OPERATOR]) {
        return l > r;
    }
    if ([op isEqualToString:GREATER_THAN_EQUAL_OPERATOR]) {
        return l >= r;
    }
    if ([op isEqualToString:LESS_THAN_OPERATOR]) {
        return l < r;
    }
    if ([op isEqualToString:LESS_THAN_EQUAL_OPERATOR]) {
        return l <= r;
    }

    return NO;
}

+ (MPBoolean *)evaluateComparison:(NSDictionary *)node properties:(NSDictionary *)properties withError:(NSError *__autoreleasing *)error {
    NSArray *supportedOperators = @[GREATER_THAN_OPERATOR, GREATER_THAN_EQUAL_OPERATOR, LESS_THAN_OPERATOR, LESS_THAN_EQUAL_OPERATOR];
    if (![node objectForKey:OPERATOR_KEY] || !([supportedOperators containsObject:node[OPERATOR_KEY]])) {
        if (error) {
            *error = [self error:@"invalid comparison operator"];
        }
        return nil;
    }
    if (![node objectForKey:CHILDREN_KEY]  || !([(NSArray *)node[CHILDREN_KEY] isKindOfClass:[NSArray class]] &&
                                                ([(NSArray *)node[CHILDREN_KEY] count] == 2))) {
        if (error) {
            *error = [self error:@"invalid comparison operator"];
        }
        return nil;
    }
    
    id l = [self evaluateNode:node[CHILDREN_KEY][kLEFT] properties:properties withError:error];
    if (error && *error) {
        return nil;
    }
    id r = [self evaluateNode:node[CHILDREN_KEY][kRIGHT] properties:properties withError:error];
    if (error && *error) {
        return nil;
    }
    
    BOOL b = NO;
    
    if ([(NSNumber *)l isKindOfClass:[NSNumber class]] && [(NSNumber *)r isKindOfClass:[NSNumber class]]) {
        b = [self compareDoubles:[(NSNumber *)l doubleValue] r:[(NSNumber *)r doubleValue] op:node[OPERATOR_KEY]];
    } else if ([(NSDate *)l isKindOfClass:[NSDate class]] && [(NSDate *)r isKindOfClass:[NSDate class]]) {
        b = [self compareDoubles:[(NSDate *)l timeIntervalSince1970] r:[(NSDate *)r timeIntervalSince1970] op:node[OPERATOR_KEY]];
    } else if ([(NSString *)l isKindOfClass:[NSString class]] && [(NSString *)r isKindOfClass:[NSString class]]) {
        NSString *op = node[OPERATOR_KEY];
        NSString *ls = [(NSString *)l lowercaseString];
        NSString *rs = [(NSString *)r lowercaseString];
        if ([op isEqualToString:GREATER_THAN_OPERATOR]) {
            b = [ls compare:rs] == NSOrderedDescending;
        } else if ([op isEqualToString:GREATER_THAN_EQUAL_OPERATOR]) {
            b = [ls compare:rs] == NSOrderedDescending || [ls compare:rs] == NSOrderedSame;
        } else if ([op isEqualToString:LESS_THAN_OPERATOR]) {
            b = [ls compare:rs] == NSOrderedAscending;
        } else if ([op isEqualToString:LESS_THAN_EQUAL_OPERATOR]) {
            b = [ls compare:rs] == NSOrderedAscending || [ls compare:rs] == NSOrderedSame;
        }
    }

    return [[MPBoolean alloc] init:b];
}

+ (MPBoolean *)evaluateDefined:(NSDictionary *)node properties:(NSDictionary *)properties withError:(NSError *__autoreleasing *)error {
    NSArray *supportedOperators = @[DEFINED_OPERATOR, NOT_DEFINED_OPERATOR];
    if (![node objectForKey:OPERATOR_KEY] || !([supportedOperators containsObject:node[OPERATOR_KEY]])) {
        if (error) {
            *error = [self error:@"invalid operator: defined"];
        }
        return nil;
    }
    if (![node objectForKey:CHILDREN_KEY]  || !([(NSArray *)node[CHILDREN_KEY] isKindOfClass:[NSArray class]] &&
                                                ([(NSArray *)node[CHILDREN_KEY] count] == 1))) {
        if (error) {
            *error = [self error:@"invalid operator: defined"];
        }
        return nil;
    }
    NSObject *child = [self evaluateNode:node[CHILDREN_KEY][kLEFT] properties:properties withError:error];
    if (error && *error) {
        return nil;
    }
    BOOL b = child ? YES : NO;
    if ([node[OPERATOR_KEY] isEqualToString:NOT_DEFINED_OPERATOR]) {
        b = !b;
    }

    return [[MPBoolean alloc] init: b];
}

+ (MPBoolean *)evaluateNot:(NSDictionary *)node properties:(NSDictionary *)properties withError:(NSError *__autoreleasing *)error {
    if (![node objectForKey:OPERATOR_KEY] || ![node[OPERATOR_KEY] isEqualToString:NOT_OPERATOR]) {
        if (error) {
            *error = [self error:@"invalid operator: not"];
        }
        return nil;
    }
    if (![node objectForKey:CHILDREN_KEY]  || !([(NSArray *)node[CHILDREN_KEY] isKindOfClass:[NSArray class]] &&
                                                ([(NSArray *)node[CHILDREN_KEY] count] == 1))) {
        if (error) {
            *error = [self error:@"invalid operator: not"];
        }
        return nil;
    }
    NSObject *child = [self evaluateNode:node[CHILDREN_KEY][kLEFT] properties:properties withError:error];
    if (error && *error) {
        return nil;
    }
    if ([(MPBoolean *)child isKindOfClass:[MPBoolean class]]) {
        return [[MPBoolean alloc] init: ![(MPBoolean *)child value]];
    }
    if ([(NSNumber *)child isKindOfClass:[NSNumber class]]) {
        return [[MPBoolean alloc] init: ![(NSNumber *)child boolValue]];
    }
    if (child == nil) {
        return [[MPBoolean alloc] init: YES];
    }

    return nil;
}


+ (NSDate *)evaluateWindow:(NSDictionary *)value withError:(NSError *__autoreleasing *)error {
    if (![value objectForKey:WINDOW_KEY] || ![(NSDictionary *)value[WINDOW_KEY] isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = [self error:@"invalid or missing required key window"];
        }
        return nil;
    }
    NSDictionary *window = [value objectForKey:WINDOW_KEY];
    if (![window objectForKey:VALUE_KEY]  || ![(NSNumber *)window[VALUE_KEY] isKindOfClass:[NSNumber class]]) {
        if (error) {
            *error = [self error:@"invalid or missing required key value"];
        }
        return nil;
    }
    NSNumber *unitValue = window[VALUE_KEY];
    if (![window objectForKey:UNIT_KEY]  || ![(NSString *)window[UNIT_KEY] isKindOfClass:[NSString class]]) {
        if (error) {
            *error = [self error:@"invalid or missing required key unit"];
        }
        return nil;
    }
    NSString *unit = window[UNIT_KEY];
    NSDate *date = [self currentDate];
    if ([unit isEqualToString:HOUR_KEY]) {
        return [date dateByAddingTimeInterval:(-1 * unitValue.doubleValue * 60 * 60)];
    }
    if ([unit isEqualToString:DAY_KEY]) {
        return [date dateByAddingTimeInterval:(-1 * unitValue.doubleValue * 24 * 60 * 60)];
    }
    if ([unit isEqualToString:WEEK_KEY]) {
        return [date dateByAddingTimeInterval:(-1 * unitValue.doubleValue * 7 * 24 * 60 * 60)];
    }
    if ([unit isEqualToString:MONTH_KEY]) {
        return [date dateByAddingTimeInterval:(-1 * unitValue.doubleValue * 30 * 24 * 60 * 60)];
    }
    if (error) {
        *error = [self error:@"invalid unit for window"];
    }

    return nil;
}

+ (id)evaluateOperand:(NSDictionary *)node properties:(NSDictionary *)properties withError:(NSError *__autoreleasing *)error {
    if (![node objectForKey:PROPERTY_KEY] || ![node[PROPERTY_KEY] isKindOfClass:[NSString class]]) {
        if (error) {
            *error = [self error:@"invalid or missing required key property"];
        }
        return nil;
    }
    if (![node objectForKey:VALUE_KEY]  || !([node[PROPERTY_KEY] isKindOfClass:[NSString class]] ||
                                             [node[PROPERTY_KEY] isKindOfClass:[NSDictionary class]])) {
        if (error) {
            *error = [self error:@"invalid or missing required key value"];
        }
        return nil;
    }
    
    NSString *property = node[PROPERTY_KEY];
    id value = node[VALUE_KEY];
    if ([property isEqualToString:EVENT_KEY]) {
        if ([value isKindOfClass:[NSString class]]) {
            return properties[(NSString *)value];
        }
        *error = [self error:@"invalid type for event property name"];
        return nil;
    }
    if ([property isEqualToString:LITERAL_KEY]) {
        if ([value isKindOfClass:[NSString class]] && [(NSString *)value isEqualToString:NOW_LITERAL]) {
            return [self currentDate];
        }
        if ([value isKindOfClass:[NSDictionary class]]) {
            return [self evaluateWindow:value withError:error];
        }
        return value;
    }
    
    if (error) {
        *error = [self error:@"invalid value for property key"];
    }

    return nil;
}

+ (id)evaluateOperator:(NSDictionary *)node properties:(NSDictionary *)properties withError:(NSError *__autoreleasing *)error {
    if (![node objectForKey:OPERATOR_KEY] || ![(NSString *)node[OPERATOR_KEY] isKindOfClass:[NSString class]]) {
        if (error) {
            *error = [self error:@"invalid operator key"];
        }
        return nil;
    }
    
    NSString *op = node[OPERATOR_KEY];
    if ([op isEqualToString:AND_OPERATOR]) {
        return [self evaluateAnd:node properties:properties withError:error];
    }
    if ([op isEqualToString:OR_OPERATOR]) {
        return [self evaluateOr:node properties:properties withError:error];
    }
    if ([@[IN_OPERATOR, NOT_IN_OPERATOR] containsObject:op]) {
        return [self evaluateIn:node properties:properties withError:error];
    }
    if ([op isEqualToString:PLUS_OPERATOR]) {
        return [self evaluatePlus:node properties:properties withError:error];
    }
    if ([@[MINUS_OPERATOR, MUL_OPERATOR, DIV_OPERATOR, MOD_OPERATOR] containsObject:op]) {
        return [self evaluateArithmetic:node properties:properties withError:error];
    }
    if ([@[EQUALS_OPERATOR, NOT_EQUALS_OPERATOR] containsObject:op]) {
        return [self evaluateEquality:node properties:properties withError:error];
    }
    if ([@[GREATER_THAN_OPERATOR, GREATER_THAN_EQUAL_OPERATOR, LESS_THAN_OPERATOR, LESS_THAN_EQUAL_OPERATOR] containsObject:op]) {
        return [self evaluateComparison:node properties:properties withError:error];
    }
    if ([op isEqualToString:BOOLEAN_OPERATOR]) {
        return [self evaluateBoolean:node properties:properties withError:error];
    }
    if ([op isEqualToString:STRING_OPERATOR]) {
        return [self evaluateString:node properties:properties withError:error];
    }
    if ([op isEqualToString:LIST_OPERATOR]) {
        return [self evaluateList:node properties:properties withError:error];
    }
    if ([op isEqualToString:NUMBER_OPERATOR]) {
        return [self evaluateNumber:node properties:properties withError:error];
    }
    if ([op isEqualToString:DATETIME_OPERATOR]) {
        return [self evaluateDateTime:node properties:properties withError:error];
    }
    if ([@[DEFINED_OPERATOR, NOT_DEFINED_OPERATOR] containsObject:op]) {
        return [self evaluateDefined:node properties:properties withError:error];
    }
    if ([op isEqualToString:NOT_OPERATOR]) {
        return [self evaluateNot:node properties:properties withError:error];
    }
    
    if (error) {
        *error = [self error:[NSString stringWithFormat:@"unknown operator %@", op]];
    }

    return nil;
}

+ (id)evaluateNode:(NSDictionary *)node properties:(NSDictionary *)properties withError:(NSError *__autoreleasing *)error {
    if ([node objectForKey:PROPERTY_KEY]) {
        return [self evaluateOperand:node properties:properties withError:error];
    }
    return [self evaluateOperator:node properties:properties withError:error];
}

+ (id)evaluate:(NSDictionary *)selector properties:(NSDictionary *)properties withError:(NSError *__autoreleasing *)error {
    id value = [self evaluateOperator:selector properties:properties withError:error];
    if (error && *error) {
        return nil;
    }
    if (value == nil) {
        return nil;
    }

    return [[NSNumber alloc] initWithBool:[self toBoolean:value]];
}

@end
