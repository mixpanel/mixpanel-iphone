//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import <objc/runtime.h>
#import "NSInvocation+MPHelpers.h"

typedef union {
    __unsafe_unretained id  _id;
    char                    _chr;
    unsigned char           _uchr;
    short                   _sht;
    unsigned short          _usht;
    int                     _int;
    unsigned int            _uint;
    long                    _lng;
    unsigned long           _ulng;
    long long               _lng_lng;
    unsigned long long      _ulng_lng;
    float                   _flt;
    double                  _dbl;
    _Bool                   _bool;
    CGRect                  _CGRect;
    CGPoint                 _CGPoint;
    CGSize                  _CGSize;
    CGAffineTransform       _CGAffineTransform;
    CATransform3D           _CATransform3D;
    SEL                     _sel;
    const void *            _ptr;
    CFTypeRef               _cfTypeRef;
} MPUnionOfObjCTypes;

static void MPFillArgument(MPUnionOfObjCTypes *arg, id argumentValue, const char *argumentType)
{
    NSCAssert(strlen(argumentType) == 1, @"Structures and other complex argument typeas currently not supported.");

    switch (argumentType[0])
    {
        case _C_ID:       arg->_id       = argumentValue;                            break;
        case _C_CHR:      arg->_chr      = [argumentValue charValue];                break;
        case _C_UCHR:     arg->_uchr     = [argumentValue unsignedCharValue];        break;
        case _C_SHT:      arg->_sht      = [argumentValue shortValue];               break;
        case _C_USHT:     arg->_usht     = [argumentValue unsignedShortValue];       break;
        case _C_INT:      arg->_int      = [argumentValue intValue];                 break;
        case _C_UINT:     arg->_uint     = [argumentValue unsignedIntValue];         break;
        case _C_LNG:      arg->_lng      = [argumentValue longValue];                break;
        case _C_ULNG:     arg->_ulng     = [argumentValue unsignedLongValue];        break;
        case _C_LNG_LNG:  arg->_lng_lng  = [argumentValue longLongValue];            break;
        case _C_ULNG_LNG: arg->_ulng_lng = [argumentValue unsignedLongLongValue];    break;
        case _C_FLT:      arg->_flt      = [argumentValue floatValue];               break;
        case _C_DBL:      arg->_dbl      = [argumentValue doubleValue];              break;
        case _C_BOOL:     arg->_bool     = [argumentValue boolValue];                break;
        case _C_SEL:      arg->_sel      = NSSelectorFromString(argumentValue);      break;
        default:
            NSCAssert(NO, @"Currently unsupported argument type!");
    }
}

@implementation NSInvocation (MPHelpers)

- (void)mp_setArgumentsFromArray:(NSArray *)argumentArray
{
    NSParameterAssert([argumentArray count] == ([self.methodSignature numberOfArguments] - 2));

    NSUInteger argumentCount = [argumentArray count];
    MPUnionOfObjCTypes *arguments = calloc(argumentCount, sizeof(MPUnionOfObjCTypes));
    memset(arguments, 0, sizeof(MPUnionOfObjCTypes) * argumentCount);

    for (NSUInteger i = 0; i < argumentCount; ++i)
    {
        NSUInteger argumentIndex = 2 + i;
        const char *argumentType = [self.methodSignature getArgumentTypeAtIndex:argumentIndex];

        MPFillArgument((arguments + i), argumentArray[i], argumentType);

        [self setArgument:(arguments + i) atIndex:(NSInteger)argumentIndex];
    }

    free(arguments);
}

- (id)mp_returnValue
{
    NSMethodSignature *methodSignature = self.methodSignature;
    const char *objCType = [methodSignature methodReturnType];

    MPUnionOfObjCTypes val;
    if ([methodSignature methodReturnLength] <= sizeof(val))
    {
        [self getReturnValue:&val];

        switch (objCType[0])
        {
            case _C_ID:       return val._id;
            case _C_CHR:      return @(val._chr);
            case _C_UCHR:     return @(val._uchr);
            case _C_SHT:      return @(val._sht);
            case _C_USHT:     return @(val._usht);
            case _C_INT:      return @(val._int);
            case _C_UINT:     return @(val._uint);
            case _C_LNG:      return @(val._lng);
            case _C_ULNG:     return @(val._ulng);
            case _C_LNG_LNG:  return @(val._lng_lng);
            case _C_ULNG_LNG: return @(val._ulng_lng);
            case _C_FLT:      return @(val._flt);
            case _C_DBL:      return @(val._dbl);
            case _C_BOOL:     return @(val._bool);
            case _C_SEL:      return NSStringFromSelector(val._sel);
            case _C_STRUCT_B: return [NSValue valueWithBytes:&val objCType:objCType];
            case _C_PTR:
            {
                if ((strcmp(objCType, @encode(CGImageRef)) == 0 && CFGetTypeID(val._cfTypeRef) == CGImageGetTypeID()) ||
                    (strcmp(objCType, @encode(CGColorRef)) == 0 && CFGetTypeID(val._cfTypeRef) == CGColorGetTypeID()))
                {
                    return (__bridge id)(val._cfTypeRef);
                }

                NSAssert(NO, @"Currently unsupported return type!");
                break;
            }
            default:
                NSAssert(NO, @"Currently unsupported return type!");
                break;

        }
    }
    else
    {
        NSAssert(NO, @"Return value too large!");
    }

    return nil;
}

@end
