#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif

#import "MixpanelPresentationObject.h"

@implementation MixpanelPresentationObject

- (instancetype)initWithID:(NSUInteger)ID objectType:(MPPresentationObjectType)objectType {
    if (self = [super init]) {
        _ID = ID;
        _objectType = objectType;
    }
    return self;
}

@end
