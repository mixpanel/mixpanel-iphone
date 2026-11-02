//
//  MixpanelIdentity.h
//  Mixpanel
//
//  Copyright © Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*!
 Names who events and profile updates belong to.

 Mixpanel owns the device id, so it reports a complete identity through the
 <code>identity</code> property and takes only <code>userId</code> and
 <code>companyId</code> when identifying:

 <pre>
 [mixpanel identifyWithIdentity:[[MixpanelIdentity alloc] initWithUserId:@"user_123" companyId:@"acme"]];
 MixpanelIdentity *current = mixpanel.identity;
 </pre>

 On a project that uses hierarchical groups, Mixpanel builds the user's distinct id from
 <code>$company_id</code> and <code>$user_id</code>, so the company is part of the user's
 identity: the same user id in two companies is two users. Other projects ignore
 <code>companyId</code>.

 Every value is nullable so that a missing value is reported by the method it is passed to.
 Instances are immutable, and two identities with the same values are equal.
 */
@interface MixpanelIdentity : NSObject <NSCopying>

/*!
 The user's id. On a hierarchical groups project it only needs to be unique within the company.
 */
@property (nonatomic, readonly, copy, nullable) NSString *userId;

/*!
 The id of the user's top-level company, on a hierarchical groups project.
 */
@property (nonatomic, readonly, copy, nullable) NSString *companyId;

/*!
 The device id Mixpanel assigned. Events that carry it are attributed to the device until the
 user is known, then follow the user.
 */
@property (nonatomic, readonly, copy, nullable) NSString *deviceId;

/*!
 Creates an identity for a user and, on a hierarchical groups project, their company.

 @param userId      the user's id
 @param companyId   the user's company id, or nil on a project without hierarchical groups
 */
- (instancetype)initWithUserId:(nullable NSString *)userId
                     companyId:(nullable NSString *)companyId;

/*!
 Creates an identity with a device id, as Mixpanel reports through its <code>identity</code>
 property. Identifying ignores the device id, since Mixpanel owns it.

 @param userId      the user's id
 @param companyId   the user's company id, or nil on a project without hierarchical groups
 @param deviceId    the device id Mixpanel assigned
 */
- (instancetype)initWithUserId:(nullable NSString *)userId
                     companyId:(nullable NSString *)companyId
                      deviceId:(nullable NSString *)deviceId NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
