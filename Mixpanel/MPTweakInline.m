/**
 Copyright (c) 2014-present, Facebook, Inc.
 All rights reserved.
 
 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree. An additional grant
 of patent rights can be found in the PATENTS file in the same directory.
 */

#import <dlfcn.h>
#import <libkern/OSAtomic.h>
#import <mach-o/dyld.h>
#import <mach-o/getsect.h>
#import "MPTweak.h"
#import "MPTweakInline.h"
#import "MPTweakStore.h"
#include <stdatomic.h>

static MPTweak *_MPTweakCreateWithEntry(NSString *name, mp_tweak_entry *entry)
{
    NSString *encoding = [NSString stringWithFormat:@"%s", *entry->encoding];
    MPTweak *tweak = [[MPTweak alloc] initWithName:name andEncoding:encoding];
    
    if (strcmp(*entry->encoding, @encode(BOOL)) == 0) {
        tweak.defaultValue = @(*(BOOL *)entry->value);
    } else if (strcmp(*entry->encoding, @encode(float)) == 0) {
        tweak.defaultValue = @(*(float *)entry->value);
        if (entry->min != NULL && entry->max != NULL) {
            tweak.minimumValue = @(*(float *)entry->min);
            tweak.maximumValue = @(*(float *)entry->max);
        }
    } else if (strcmp(*entry->encoding, @encode(double)) == 0) {
        tweak.defaultValue = @(*(double *)entry->value);
        if (entry->min != NULL && entry->max != NULL) {
            tweak.minimumValue = @(*(double *)entry->min);
            tweak.maximumValue = @(*(double *)entry->max);
        }
    } else if (strcmp(*entry->encoding, @encode(short)) == 0) {
        tweak.defaultValue = @(*(short *)entry->value);
        if (entry->min != NULL && entry->max != NULL) {
            tweak.minimumValue = @(*(short *)entry->min);
            tweak.maximumValue = @(*(short *)entry->max);
        }
    } else if (strcmp(*entry->encoding, @encode(unsigned short)) == 0) {
        tweak.defaultValue = @(*(unsigned short int *)entry->value);
        if (entry->min != NULL && entry->max != NULL) {
            tweak.minimumValue = @(*(unsigned short *)entry->min);
            tweak.maximumValue = @(*(unsigned short *)entry->max);
        }
    } else if (strcmp(*entry->encoding, @encode(int)) == 0) {
        tweak.defaultValue = @(*(int *)entry->value);
        if (entry->min != NULL && entry->max != NULL) {
            tweak.minimumValue = @(*(int *)entry->min);
            tweak.maximumValue = @(*(int *)entry->max);
        }
    } else if (strcmp(*entry->encoding, @encode(uint)) == 0) {
        tweak.defaultValue = @(*(uint *)entry->value);
        if (entry->min != NULL && entry->max != NULL) {
            tweak.minimumValue = @(*(uint *)entry->min);
            tweak.maximumValue = @(*(uint *)entry->max);
        }
    } else if (strcmp(*entry->encoding, @encode(long)) == 0) {
        tweak.defaultValue = @(*(long *)entry->value);
        if (entry->min != NULL && entry->max != NULL) {
            tweak.minimumValue = @(*(long *)entry->min);
            tweak.maximumValue = @(*(long *)entry->max);
        }
    } else if (strcmp(*entry->encoding, @encode(unsigned long)) == 0) {
        tweak.defaultValue = @(*(unsigned long *)entry->value);
        if (entry->min != NULL && entry->max != NULL) {
            tweak.minimumValue = @(*(unsigned long *)entry->min);
            tweak.maximumValue = @(*(unsigned long *)entry->max);
        }
    } else if (strcmp(*entry->encoding, @encode(long long)) == 0) {
        tweak.defaultValue = @(*(long long *)entry->value);
        if (entry->min != NULL && entry->max != NULL) {
            tweak.minimumValue = @(*(long long *)entry->min);
            tweak.maximumValue = @(*(long long *)entry->max);
        }
    } else if (strcmp(*entry->encoding, @encode(unsigned long long)) == 0) {
        tweak.defaultValue = @(*(unsigned long long *)entry->value);
        if (entry->min != NULL && entry->max != NULL) {
            tweak.minimumValue = @(*(unsigned long long *)entry->min);
            tweak.maximumValue = @(*(unsigned long long *)entry->max);
        }
    } else if (*entry->encoding[0] == '[') {
        // Assume it's a C string.
        tweak.defaultValue = [NSString stringWithUTF8String:entry->value];
    } else if (strcmp(*entry->encoding, @encode(id)) == 0) {
        tweak.defaultValue = *((__unsafe_unretained id *)entry->value);
    } else {
        NSCAssert(NO, @"Unknown encoding %s for tweak %@. Value was %p.", *entry->encoding, *entry->name, entry->value);
        tweak = nil;
    }
    
    return tweak;
}

@interface _MPTweakInlineLoader : NSObject

@end

@implementation _MPTweakInlineLoader

+ (void)load {
    static atomic_uint_fast32_t _tweaksLoaded = 0;
    
    if (atomic_fetch_or(&_tweaksLoaded, 1)) {
        return;
    }
    
#ifdef __LP64__
    typedef struct mach_header_64 mp_tweak_header;
#else
    typedef struct mach_header mp_tweak_header;
#endif
    
    MPTweakStore *store = [MPTweakStore sharedInstance];
    
    Dl_info info;
    dladdr((void *)&_MPTweakCreateWithEntry, &info);
    
    uint32_t image_count = _dyld_image_count();
    for (uint32_t image_index = 0; image_index < image_count; image_index++) {
        const mp_tweak_header *mach_header = (const mp_tweak_header *)_dyld_get_image_header(image_index);
        
        unsigned long size;
        mp_tweak_entry *data = (mp_tweak_entry *)getsectiondata(mach_header, MPTweakSegmentName, MPTweakSectionName, &size);
        if (data == NULL) {
            continue;
        }
        size_t count = size / sizeof(mp_tweak_entry);
        for (size_t i = 0; i < count; i++) {
            mp_tweak_entry *entry = &data[i];
            if (entry->name == nil) {
                continue;
            }
            NSString *name = [NSString stringWithString:*entry->name];
            if ([store tweakWithName:name] == nil) {
                MPTweak *tweak = _MPTweakCreateWithEntry(name, entry);
                if (tweak != nil) {
                    [store addTweak:tweak];
                }
            }
        }
    }
}

@end

