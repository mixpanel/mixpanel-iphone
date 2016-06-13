//
//  MPSurveyCoordinator.h
//  Mixpanel
//
//  Created by Sam Green on 6/12/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MPSurvey;

NS_ASSUME_NONNULL_BEGIN

@interface MPSurveyCoordinator : NSObject

@property (nonatomic, readonly) BOOL isSurveyAvailable;
@property (nonatomic, readonly, nullable) NSArray<MPSurvey *> *availableSurveys;

- (void)presentSurveyFromTopViewController:(MPSurvey *)survey;

- (void)showSurvey:(MPSurvey *)survey;
- (void)showSurvey:(MPSurvey *)survey withAlert:(BOOL)showAlert;

- (void)markSurvey:(MPSurvey *)survey
             shown:(BOOL)shown
   withAnswerCount:(NSUInteger)answerCount;

@end

NS_ASSUME_NONNULL_END
