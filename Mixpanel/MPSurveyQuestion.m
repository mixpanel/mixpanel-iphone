#import "MPLogger.h"
#import "MPSurveyQuestion.h"

static NSString *MPSurveyQuestionTypeMultipleChoice = @"multiple_choice";
static NSString *MPSurveyQuestionTypeText = @"text";

@interface MPSurveyQuestion ()

@property (nonatomic) NSUInteger ID;
@property (nonatomic, strong) NSString *type;
@property (nonatomic, strong) NSString *prompt;

- (instancetype)initWithID:(NSUInteger)ID type:(NSString *)type andPrompt:(NSString *)prompt;

@end

@interface MPSurveyMultipleChoiceQuestion ()

@property (nonatomic, strong) NSArray *choices;

- (instancetype)initWithID:(NSUInteger)ID type:(NSString *)type prompt:(NSString *)prompt andChoices:(NSArray *)choices;

@end

@implementation MPSurveyQuestion

+ (MPSurveyQuestion *)questionWithJSONObject:(NSDictionary *)object
{
    if (object == nil) {
        MPLogError(@"question json object should not be nil");
        return nil;
    }
    NSNumber *ID = object[@"id"];
    if (!([ID isKindOfClass:[NSNumber class]] && ID.integerValue > 0)) {
        MPLogError(@"invalid question id: %@", ID);
        return nil;
    }
    NSString *prompt = object[@"prompt"];
    if (![prompt isKindOfClass:[NSString class]]) {
        MPLogError(@"invalid question prompt: %@", prompt);
        return nil;
    }
    NSDictionary *extraData = object[@"extra_data"];
    if (![extraData isKindOfClass:[NSDictionary class]]) {
        MPLogError(@"invalid question extra data: %@", extraData);
        return nil;
    }
    NSString *type = object[@"type"];
    if (![type isKindOfClass:[NSString class]]) {
        MPLogError(@"invalid question type: %@", type);
        return nil;
    }
    if ([type isEqualToString:MPSurveyQuestionTypeMultipleChoice]) {
        NSArray *choices = extraData[@"$choices"];
        return [[MPSurveyMultipleChoiceQuestion alloc] initWithID:ID.unsignedIntegerValue
                                                             type:type
                                                           prompt:prompt
                                                       andChoices:choices];
    } else if ([type isEqualToString:MPSurveyQuestionTypeText]) {
        return [[MPSurveyTextQuestion alloc] initWithID:ID.unsignedIntegerValue
                                                   type:type
                                              andPrompt:prompt];
    }
    MPLogError(@"unknown question type: %@", type);
    return nil;
}

- (instancetype)initWithID:(NSUInteger)ID type:(NSString *)type andPrompt:(NSString *)prompt
{
    if (self = [super init]) {
        BOOL valid = NO;
        _ID = ID;
        if ([type isEqualToString:MPSurveyQuestionTypeMultipleChoice] || [type isEqualToString:MPSurveyQuestionTypeText]) {
            self.type = type;
            if (prompt.length > 0) {
                self.prompt = prompt;
                valid = YES;
            } else {
                MPLogError(@"invalid question type: %@", type);
            }
        } else {
            MPLogError(@"invalid question type: %@", type);
        }
        if (!valid) {
            self = nil;
        }
    }
    return self;
}


@end

@implementation MPSurveyMultipleChoiceQuestion

- (instancetype)initWithID:(NSUInteger)ID type:(NSString *)type prompt:(NSString *)prompt andChoices:(NSArray *)choices
{
    if (choices.count > 0) {
        if (self = [super initWithID:ID type:type andPrompt:prompt]) {
            self.choices = choices;
        }
    } else {
        MPLogError(@"invalid choices: %@", choices);
    }
    return self;
}


@end

@implementation MPSurveyTextQuestion

@end
