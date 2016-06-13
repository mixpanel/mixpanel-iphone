//
//  MPSurveyCoordinator.m
//  Mixpanel
//
//  Created by Sam Green on 6/12/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MPSurveyCoordinator.h"
#import "MPSurveyNavigationController.h"
#import "MPSurvey.h"
#import "UIView+MPHelpers.h"
#import "MPLogger.h"
#import "MPInterfaceUtils.h"
#import "MPResources.h"

@interface MPSurveyCoordinator () <MPSurveyNavigationControllerDelegate>

@property (nonatomic, strong) NSArray *surveys;
@property (nonatomic, strong) MPSurvey *currentSurvey;
@end

@implementation MPSurveyCoordinator

#pragma mark - MPSurveyNavigationControllerDelegate
- (void)surveyController:(MPSurveyNavigationController *)controller
 wasDismissedWithAnswers:(NSArray *)answers {
    
}

#pragma mark - Surveys
- (BOOL)isSurveyAvailable {
    return (self.surveys.count > 0);
}

- (NSArray<MPSurvey *> *)availableSurveys {
    return self.surveys;
}

- (void)presentSurveyWithRootViewController:(MPSurvey *)survey {
    UIViewController *topPresentedViewController = [MPInterfaceUtils topPresentedViewController];
    if ([MPInterfaceUtils canPresentFromViewController:topPresentedViewController]) {
        UIStoryboard *storyboard = [MPResources surveyStoryboard];
        MPSurveyNavigationController *controller = [storyboard instantiateViewControllerWithIdentifier:@"MPSurveyNavigationController"];
        
        controller.survey = survey;
        controller.delegate = self;
        controller.backgroundImage = [topPresentedViewController.view mp_snapshotImage];
        
        [topPresentedViewController presentViewController:controller
                                                 animated:YES
                                               completion:^{
                                                   self.currentSurvey = survey;
                                               }];
    }
}

- (void)showSurvey:(MPSurvey *)survey withAlert:(BOOL)showAlert {
    if (survey) {
        dispatch_async(dispatch_get_main_queue(), ^{
            //            if (self.currentlyShowingNotification) {
            //                MixpanelError(@"%@ already showing in-app notification: %@", self, self.currentlyShowingNotification);
            //            } else {
            self.currentSurvey = survey;
            
            if (showAlert) {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"We'd love your feedback!"
                                                                               message:@"Mind taking a quick survey?"
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                
                UIAlertAction *noAction = [UIAlertAction actionWithTitle:@"No, Thanks"
                                                                   style:UIAlertActionStyleCancel
                                                                 handler:^(UIAlertAction *action) {
                                                                     if (self.currentSurvey) {
                                                                         [self markSurvey:self.currentSurvey
                                                                                    shown:NO
                                                                          withAnswerCount:0];
                                                                         self.currentSurvey = nil;
                                                                     }
                                                                 }];
                [alert addAction:noAction];
                
                UIAlertAction *yesAction = [UIAlertAction actionWithTitle:@"Sure"
                                                                    style:UIAlertActionStyleDefault
                                                                  handler:^(UIAlertAction *action) {
                                                                      if (self.currentSurvey) {
                                                                          [self presentSurveyWithRootViewController:self.currentSurvey];
                                                                      }
                                                                  }];
                [alert addAction:yesAction];
                
                [[MPInterfaceUtils topPresentedViewController] presentViewController:alert
                                                                            animated:YES
                                                                          completion:nil];
            }
        });
    } else {
        MixpanelError(@"%@ cannot show nil survey", self);
    }
}

- (void)showSurvey:(MPSurvey *)survey {
    [self showSurvey:survey withAlert:NO];
}

- (void)showSurvey {
    [self checkForSurveysWithCompletion:^(NSArray *surveys) {
        if (surveys.count > 0) {
            [self showSurvey:surveys.firstObject];
        }
    }];
}

- (void)showSurveyWithID:(NSUInteger)ID {
    [self checkForSurveysWithCompletion:^(NSArray *surveys) {
        for (MPSurvey *survey in surveys) {
            if (survey.ID == ID) {
                [self showSurvey:survey];
                break;
            }
        }
    }];
}

- (void)markSurvey:(MPSurvey *)survey
             shown:(BOOL)shown
   withAnswerCount:(NSUInteger)count {
    MixpanelDebug(@"%@ marking survey shown: %@, %@", self, @(survey.collectionID), _shownSurveyCollections);
    [_shownSurveyCollections addObject:@(survey.collectionID)];
    [self.people append:@{@"$surveys": @(survey.ID), @"$collections": @(survey.collectionID)}];
    
    if (![survey.name isEqualToString:@"$ignore"]) {
        [self track:@"$show_survey" properties:@{@"survey_id": @(survey.ID),
                                                 @"collection_id": @(survey.collectionID),
                                                 @"$survey_shown": @(shown),
                                                 @"$answer_count": @(count)
                                                 }];
    }
}

- (void)surveyController:(MPSurveyNavigationController *)controller
 wasDismissedWithAnswers:(NSArray *)answers {
    [controller.presentingViewController dismissViewControllerAnimated:YES completion:nil];
    self.currentSurvey = nil;
    if ([controller.survey.name isEqualToString:@"$ignore"]) {
        MixpanelDebug(@"%@ not sending survey %@ result", self, controller.survey);
    } else {
        [self markSurvey:controller.survey shown:YES withAnswerCount:answers.count];
        NSUInteger i = 0;
        for (id answer in answers) {
            if (i == 0) {
                [self.people append:@{@"$answers": answer, @"$responses": @(controller.survey.collectionID)}];
            } else {
                [self.people append:@{@"$answers": answer}];
            }
            i++;
        }
        
        dispatch_async(_serialQueue, ^{
            [self flushPeople];
        });
    }
}

@end
