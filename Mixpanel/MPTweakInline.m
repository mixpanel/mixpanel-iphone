/**
 Copyright (c) 2014-present, Facebook, Inc.
 All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree. An additional grant
 of patent rights can be found in the PATENTS file in the same directory.
 */

#import "MPTweakInline.h"
#import "MPTweak.h"
#import "MPTweakInlineInternal.h"
#import "MPTweakCollection.h"
#import "MPTweakStore.h"
#import "MPTweakCategory.h"

#import <libkern/OSAtomic.h>
#import <mach-o/getsect.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>

#if MP_TWEAK_ENABLED

extern NSString *_MPTweakIdentifier(fb_tweak_entry *entry)
{
  return [NSString stringWithFormat:@"MPTweak:%@-%@-%@", *entry->category, *entry->collection, *entry->name];
}

static MPTweak *_MPTweakCreateWithEntry(NSString *identifier, fb_tweak_entry *entry)
{
  MPTweak *tweak = [[MPTweak alloc] initWithIdentifier:identifier];
  tweak.name = *entry->name;

  if (strcmp(*entry->encoding, @encode(BOOL)) == 0) {
    tweak.defaultValue = @(*(BOOL *)entry->value);
  } else if (strcmp(*entry->encoding, @encode(float)) == 0) {
    tweak.defaultValue = [NSNumber numberWithFloat:*(float *)entry->value];
    if (entry->min != NULL && entry->max != NULL) {
      tweak.minimumValue = [NSNumber numberWithFloat:*(float *)entry->min];
      tweak.maximumValue = [NSNumber numberWithFloat:*(float *)entry->max];
    }
  } else if (strcmp(*entry->encoding, @encode(double)) == 0) {
    tweak.defaultValue = [NSNumber numberWithDouble:*(double *)entry->value];
    if (entry->min != NULL && entry->max != NULL) {
      tweak.minimumValue = [NSNumber numberWithDouble:*(double *)entry->min];
      tweak.maximumValue = [NSNumber numberWithDouble:*(double *)entry->max];
    }
  } else if (strcmp(*entry->encoding, @encode(NSInteger)) == 0) {
    tweak.defaultValue = [NSNumber numberWithLongLong:*(long long *)entry->value];
    if (entry->min != NULL && entry->max != NULL) {
      tweak.minimumValue = [NSNumber numberWithLongLong:*(long long *)entry->min];
      tweak.maximumValue = [NSNumber numberWithLongLong:*(long long *)entry->max];
    }
  } else if (strcmp(*entry->encoding, @encode(NSUInteger)) == 0) {
    tweak.defaultValue = [NSNumber numberWithUnsignedInteger:*(NSUInteger *)entry->value];
    if (entry->min != NULL && entry->max != NULL) {
      tweak.minimumValue = [NSNumber numberWithUnsignedInteger:*(NSUInteger *)entry->min];
      tweak.maximumValue = [NSNumber numberWithUnsignedInteger:*(NSUInteger *)entry->max];
    }
  } else if (*entry->encoding[0] == '[') {
    // Assume it's a C string.
    tweak.defaultValue = [NSString stringWithUTF8String:entry->value];
  } else if (strcmp(*entry->encoding, @encode(id)) == 0) {
    tweak.defaultValue = *((__unsafe_unretained id *)entry->value);
  } else {
    NSCAssert(NO, @"Unknown encoding %s for tweak %@. Value was %p.", *entry->encoding, _MPTweakIdentifier(entry), entry->value);
    tweak = nil;
  }

  return tweak;
}

@interface _MPTweakInlineLoader : NSObject
@end

@implementation _MPTweakInlineLoader

+ (void)load
{
  static uint32_t _tweaksLoaded = 0;
  if (OSAtomicTestAndSetBarrier(1, &_tweaksLoaded)) {
    return;
  }

#ifdef __LP64__
  typedef uint64_t fb_tweak_value;
  typedef struct section_64 fb_tweak_section;
#define fb_tweak_getsectbynamefromheader getsectbynamefromheader_64
#else
  typedef uint32_t fb_tweak_value;
  typedef struct section fb_tweak_section;
#define fb_tweak_getsectbynamefromheader getsectbynamefromheader
#endif

  MPTweakStore *store = [MPTweakStore sharedInstance];

  Dl_info info;
  dladdr(&_MPTweakIdentifier, &info);

  const fb_tweak_value mach_header = (fb_tweak_value)info.dli_fbase;
  const fb_tweak_section *section = fb_tweak_getsectbynamefromheader((void *)mach_header, MPTweakSegmentName, MPTweakSectionName);

  if (section == NULL) {
    return;
  }

  for (fb_tweak_value addr = section->offset; addr < section->offset + section->size; addr += sizeof(fb_tweak_entry)) {
    fb_tweak_entry *entry = (fb_tweak_entry *)(mach_header + addr);

    MPTweakCategory *category = [store tweakCategoryWithName:*entry->category];
    if (category == nil) {
      category = [[MPTweakCategory alloc] initWithName:*entry->category];
      [store addTweakCategory:category];
    }

    MPTweakCollection *collection = [category tweakCollectionWithName:*entry->collection];
    if (collection == nil) {
      collection = [[MPTweakCollection alloc] initWithName:*entry->collection];
      [category addTweakCollection:collection];
    }

    NSString *identifier = _MPTweakIdentifier(entry);
    if ([collection tweakWithIdentifier:identifier] == nil) {
      MPTweak *tweak = _MPTweakCreateWithEntry(identifier, entry);

      if (tweak != nil) {
        [collection addTweak:tweak];
      }
    }
  }
}

@end

#endif
