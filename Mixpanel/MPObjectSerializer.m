//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import <objc/runtime.h>
#import "MPObjectSerializer.h"
#import "MPClassDescription.h"
#import "MPPropertyDescription.h"
#import "MPObjectSerializerContext.h"
#import "MPObjectSerializerConfig.h"
#import "MPEnumDescription.h"
#import "MPObjectIdentityProvider.h"

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

@interface MPObjectSerializer ()
@end

@implementation MPObjectSerializer
{
    MPObjectSerializerConfig *_configuration;
    MPObjectIdentityProvider *_objectIdentityProvider;
}

- (id)initWithConfiguration:(MPObjectSerializerConfig *)configuration objectIdentityProvider:(MPObjectIdentityProvider *)objectIdentityProvider
{
    self = [super init];
    if (self)
    {
        _configuration = configuration;
        _objectIdentityProvider = objectIdentityProvider; 
    }

    return self;
}

- (NSDictionary *)serializedObjectsWithRootObject:(id)rootObject
{
    NSParameterAssert(rootObject != nil);

    MPObjectSerializerContext *context = [[MPObjectSerializerContext alloc] initWithRootObject:rootObject];

    while ([context hasUnvisitedObjects])
    {
        [self visitObject:[context dequeueUnvisitedObject] withContext:context];
    }

    return @{
            @"objects" : [context allSerializedObjects],
            @"rootObject": [_objectIdentityProvider identifierForObject:rootObject]
    };
}

- (void)visitObject:(NSObject *)object withContext:(MPObjectSerializerContext *)context
{
    NSParameterAssert(object != nil);
    NSParameterAssert(context != nil);

    [context addVisitedObject:object];
    
    NSMutableDictionary *propertyValues = [[NSMutableDictionary alloc] init];

    MPClassDescription *classDescription = [self classDescriptionForObject:object];
    if (classDescription)
    {
        for (MPPropertyDescription *propertyDescription in [classDescription propertyDescriptions])
        {
            if ([propertyDescription shouldReadPropertyValueForObject:object])
            {
                id propertyValue = [self propertyValueForObject:object withPropertyDescription:propertyDescription context:context];
                propertyValues[propertyDescription.name] = propertyValue ?: [NSNull null];
            }
        }
    }

    NSDictionary *serializedObject = @{
        @"id": [_objectIdentityProvider identifierForObject:object],
        @"class": [self classHierarchyArrayForObject:object],
        @"properties": propertyValues
    };

    [context addSerializedObject:serializedObject];
}

- (NSArray *)classHierarchyArrayForObject:(NSObject *)object
{
    NSMutableArray *classHierarchy = [[NSMutableArray alloc] init];

    Class aClass = [object class];
    while (aClass)
    {
        [classHierarchy addObject:NSStringFromClass(aClass)];
        aClass = [aClass superclass];
    }

    return [classHierarchy copy];
}

- (NSArray *)allValuesForType:(NSString *)typeName
{
    NSParameterAssert(typeName != nil);

    MPTypeDescription *typeDescription = [_configuration typeWithName:typeName];
    if ([typeDescription isKindOfClass:[MPEnumDescription class]])
    {
        MPEnumDescription *enumDescription = (MPEnumDescription *)typeDescription;
        return [enumDescription allValues];
    }

    return @[];
}

- (NSArray *)parameterVariationsForPropertySelector:(MPPropertySelectorDescription *)selectorDescription
{
    NSAssert([selectorDescription.parameters count] <= 1, @"Currently only support selectors that take 0 to 1 arguments.");

    NSMutableArray *variations = [[NSMutableArray alloc] init];

    // TODO: write an algorithm that generates all the variations of parameter combinations.

    MPPropertySelectorParameterDescription *parameterDescription = [selectorDescription.parameters firstObject];
    if (parameterDescription)
    {
        for (id value in [self allValuesForType:parameterDescription.type])
        {
            [variations addObject:@[ value ]];
        }
    }
    else
    {
        // An empty array of parameters (for methods that have no parameters).
        [variations addObject:@[]];
    }

    return [variations copy];
}

- (void)fillArgument:(MPUnionOfObjCTypes *)arg withValue:(id)argumentValue convertedTo:(const char *)argumentType
{
    NSAssert(strlen(argumentType) == 1, @"Structures and other complex argument typeas currently not supported");

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
            NSAssert(NO, @"Currently unsupported argument type!");
    }
}

- (id)returnValueForInvocation:(NSInvocation *)invocation
{
    NSMethodSignature *methodSignature = invocation.methodSignature;
    const char *objCType = [methodSignature methodReturnType];

    MPUnionOfObjCTypes val;
    if ([methodSignature methodReturnLength] <= sizeof(val))
    {
        [invocation getReturnValue:&val];

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
        NSAssert(NO, @"Return value to large!");
    }

    return nil;
}

- (id)instanceVariableValueForObject:(id)object propertyDescription:(MPPropertyDescription *)propertyDescription
{
    NSParameterAssert(object != nil);
    NSParameterAssert(propertyDescription != nil);

    Ivar ivar = class_getInstanceVariable([object class], [propertyDescription.name UTF8String]);
    if (ivar)
    {
        const char *objCType = ivar_getTypeEncoding(ivar);

        ptrdiff_t ivarOffset = ivar_getOffset(ivar);
        const void *objectBaseAddress = (__bridge const void *)object;
        const void *ivarAddress = (((const uint8_t *)objectBaseAddress) + ivarOffset);

        switch (objCType[0])
        {
            case _C_ID:       return object_getIvar(object, ivar);
            case _C_CHR:      return @(*((char *)ivarAddress));
            case _C_UCHR:     return @(*((unsigned char *)ivarAddress));
            case _C_SHT:      return @(*((short *)ivarAddress));
            case _C_USHT:     return @(*((unsigned short *)ivarAddress));
            case _C_INT:      return @(*((int *)ivarAddress));
            case _C_UINT:     return @(*((unsigned int *)ivarAddress));
            case _C_LNG:      return @(*((long *)ivarAddress));
            case _C_ULNG:     return @(*((unsigned long *)ivarAddress));
            case _C_LNG_LNG:  return @(*((long long *)ivarAddress));
            case _C_ULNG_LNG: return @(*((unsigned long long *)ivarAddress));
            case _C_FLT:      return @(*((float *)ivarAddress));
            case _C_DBL:      return @(*((double *)ivarAddress));
            case _C_BOOL:     return @(*((_Bool *)ivarAddress));
            case _C_SEL:      return NSStringFromSelector(*((SEL*)ivarAddress));
            default:
                NSAssert(NO, @"Currently unsupported return type!");
                break;
        }
    }

    return nil;
}

- (NSInvocation *)invocationForObject:(id)object withSelectorDescription:(MPPropertySelectorDescription *)selectorDescription
{
    NSUInteger parameterCount = [selectorDescription.parameters count];

    SEL aSelector = NSSelectorFromString(selectorDescription.selectorName);
    NSAssert(aSelector != nil, @"Expected non-nil selector!");

    NSMethodSignature *methodSignature = [object methodSignatureForSelector:aSelector];
    NSAssert([methodSignature numberOfArguments] == (parameterCount + 2), @"Unexpected number of arguments!");

    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
    invocation.selector = aSelector;

    return invocation;
}

- (void)configureInvocation:(NSInvocation *)invocation withArgumentsFromArray:(NSArray *)argumentArray
{
    NSParameterAssert([argumentArray count] == ([invocation.methodSignature numberOfArguments] - 2));

    NSUInteger argumentCount = [argumentArray count];
    MPUnionOfObjCTypes *arguments = calloc(argumentCount, sizeof(MPUnionOfObjCTypes));
    memset(arguments, 0, sizeof(MPUnionOfObjCTypes) * argumentCount);

    for (NSUInteger i = 0; i < argumentCount; ++i)
    {
        NSUInteger argumentIndex = 2 + i;
        const char *argumentType = [invocation.methodSignature getArgumentTypeAtIndex:argumentIndex];

        [self fillArgument:(arguments + i) withValue:argumentArray[i] convertedTo:argumentType];
        [invocation setArgument:(arguments + i) atIndex:(NSInteger)argumentIndex];
    }

    free(arguments);
}

- (id)propertyValue:(id)propertyValue propertyDescription:(MPPropertyDescription *)propertyDescription context:(MPObjectSerializerContext *)context
{
    if (propertyValue != nil)
    {
        if ([context isVisitedObject:propertyValue])
        {
            return [_objectIdentityProvider identifierForObject:propertyValue];
        }
        else if ([self isNestedObjectType:propertyDescription.type])
        {
            [context enqueueUnvisitedObject:propertyValue];
            return [_objectIdentityProvider identifierForObject:propertyValue];
        }
        else if ([propertyValue isKindOfClass:[NSArray class]] || [propertyValue isKindOfClass:[NSSet class]])
        {
            NSMutableArray *arrayOfIdentifiers = [[NSMutableArray alloc] init];
            for (id value in propertyValue)
            {
                if ([context isVisitedObject:value] == NO)
                {
                    [context enqueueUnvisitedObject:value];
                }

                [arrayOfIdentifiers addObject:[_objectIdentityProvider identifierForObject:value]];
            }
            propertyValue = [arrayOfIdentifiers copy];
        }
    }

    return [propertyDescription.valueTransformer transformedValue:propertyValue];
}

- (id)propertyValueForObject:(NSObject *)object withPropertyDescription:(MPPropertyDescription *)propertyDescription context:(MPObjectSerializerContext *)context
{
    NSMutableArray *values = [[NSMutableArray alloc] init];
    NSDictionary *propertyValue = @{@"values" : values};

    MPPropertySelectorDescription *selectorDescription = propertyDescription.getSelectorDescription;

    if (propertyDescription.useKeyValueCoding)
    {
        // the "fast" (also also simple) path is to use KVC
        id valueForKey = [object valueForKey:selectorDescription.selectorName];

        id value = [self propertyValue:valueForKey
                   propertyDescription:propertyDescription
                               context:context];

        NSDictionary *valueDictionary = @{
                @"value" : (value ?: [NSNull null])
        };

        [values addObject:valueDictionary];
    }
    else if (propertyDescription.useInstanceVariableAccess)
    {
        id valueForIvar = [self instanceVariableValueForObject:object propertyDescription:propertyDescription];

        id value = [self propertyValue:valueForIvar
                   propertyDescription:propertyDescription
                               context:context];

        NSDictionary *valueDictionary = @{
                @"value" : (value ?: [NSNull null])
        };

        [values addObject:valueDictionary];
    }
    else
    {
        // the "slow" NSInvocation path. Required in order to invoke methods that take parameters.
        NSInvocation *invocation = [self invocationForObject:object withSelectorDescription:selectorDescription];
        NSArray *parameterVariations = [self parameterVariationsForPropertySelector:selectorDescription];

        for (NSArray *parameters in parameterVariations)
        {
            [self configureInvocation:invocation withArgumentsFromArray:parameters];
            [invocation invokeWithTarget:object];

            id returnValue = [self returnValueForInvocation:invocation];

            id value = [self propertyValue:returnValue
                       propertyDescription:propertyDescription
                                   context:context];

            NSDictionary *valueDictionary = @{
                @"where" : @{ @"parameters" : parameters },
                @"value" : (value ?: [NSNull null])
            };

            [values addObject:valueDictionary];
        }
    }

    return propertyValue;
}

- (BOOL)isNestedObjectType:(NSString *)typeName
{
    return [_configuration classWithName:typeName] != nil;
}

- (MPClassDescription *)classDescriptionForObject:(NSObject *)object
{
    NSParameterAssert(object != nil);

    Class aClass = [object class];
    while (aClass != nil)
    {
        MPClassDescription *classDescription = [_configuration classWithName:NSStringFromClass(aClass)];
        if (classDescription)
        {
            return classDescription;
        }

        aClass = [aClass superclass];
    }

    return nil;
}

@end
