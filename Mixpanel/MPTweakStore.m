/**
 Copyright (c) 2014-present, Facebook, Inc.
 All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree. An additional grant
 of patent rights can be found in the PATENTS file in the same directory.
 */

#import "MPTweak.h"
#import "MPTweakStore.h"

@implementation MPTweakStore {
  NSMutableArray *_orderedTweaks;
  NSMutableDictionary *_namedTweaks;
}

+ (instancetype)sharedInstance
{
  static MPTweakStore *sharedInstance;

  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[self alloc] init];
  });

  return sharedInstance;
}

- (instancetype)init
{
  if ((self = [super init])) {
    _orderedTweaks = [NSMutableArray arrayWithCapacity:16];
    _namedTweaks = [NSMutableDictionary dictionaryWithCapacity:16];
  }

  return self;
}

- (NSArray *)tweaks
{
  return [_orderedTweaks copy];
}

- (MPTweak *)tweakWithName:(NSString *)name
{
  return _namedTweaks[name];
}

- (void)addTweak:(MPTweak *)tweak
{
  _namedTweaks[tweak.name] = tweak;
  [_orderedTweaks addObject:tweak];
}

- (void)removeTweak:(MPTweak *)tweak
{
  _namedTweaks[tweak.name] = nil;
  [_orderedTweaks removeObject:tweak];
}

- (void)reset
{
  for (MPTweak *tweak in self.tweaks) {
      tweak.currentValue = nil;
  }
}

@end
