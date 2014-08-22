#import "HTTPConnection.h"

@interface MixpanelDummyDecideConnection : HTTPConnection

+ (int)getRequestCount;
+ (void)setDecideResponseURL:(NSURL *)url;

@end
