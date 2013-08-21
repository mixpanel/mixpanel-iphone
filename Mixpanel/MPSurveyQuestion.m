#import "MPSurveyQuestion.h"

@interface MPSurveyQuestion ()

@property(nonatomic) NSUInteger ID;
@property(nonatomic,retain) NSString *prompt;

- (id)initWithID:(NSUInteger *)ID andPrompt:(NSString *)prompt;

@end

@interface MPSurveyMultipleChoiceQuestion ()

@property(nonatomic,retain) NSArray *choices;

- (id)initWithID:(NSUInteger *)ID prompt:(NSString *)prompt andChoices:(NSArray *)choices;

@end

@implementation MPSurveyQuestion

+ (MPSurveyQuestion *)questionWithJSONObject:(NSDictionary *)object
{
    if (object == nil) {
        NSLog(@"question json object should not be nil");
        return nil;
    }
    NSNumber *ID = object[@"id"];
    if (!([ID isKindOfClass:[NSNumber class]] && [ID integerValue] > 0)) {
        NSLog(@"invalid question id: %@", ID);
        return nil;
    }
    NSString *prompt = object[@"prompt"];
    if (![prompt isKindOfClass:[NSString class]]) {
        NSLog(@"invalid question prompt: %@", prompt);
        return nil;
    }
    NSDictionary *extraData = object[@"extra_data"];
    if (![extraData isKindOfClass:[NSDictionary class]]) {
        NSLog(@"invalid question extra data: %@", extraData);
        return nil;
    }
    NSString *type = object[@"type"];
    if (![type isKindOfClass:[NSString class]]) {
        NSLog(@"invalid question type: %@", type);
        return nil;
    }
    if ([type isEqualToString:@"multiple_choice"]) {
        NSArray *choices = extraData[@"choices"];
        return [[[MPSurveyMultipleChoiceQuestion alloc] initWithID:[ID integerValue]
                                                            prompt:prompt
                                                        andChoices:choices] autorelease];
    } else if ([type isEqualToString:@"text"]) {
        return [[[MPSurveyTextQuestion alloc] initWithID:[ID integerValue]
                                               andPrompt:prompt] autorelease];
    } else {
        NSLog(@"unknown question type: %@", type);
        return nil;
    }
}

- (id)initWithID:(NSUInteger *)ID andPrompt:(NSString *)prompt
{
    if (prompt == nil || prompt.length == 0) {
        NSLog(@"invalid question prompt: %@", prompt);
        return nil;
    }
    if (self = [super init]) {
        _ID = ID;
        self.prompt = prompt;
    }
    return self;
}

- (void)dealloc
{
    _ID = nil;
    self.prompt = nil;
    [super dealloc];
}

@end

@implementation MPSurveyMultipleChoiceQuestion

- (id)initWithID:(NSUInteger *)ID prompt:(NSString *)prompt andChoices:(NSArray *)choices
{
    if (choices == nil || [choices count] == 0) {
        NSLog(@"invalid choices: %@", choices);
        return nil;
    }
    if (self = [super initWithID:ID andPrompt:prompt]) {
        self.choices = choices;
    }
    return self;
}

- (void)dealloc
{
    self.choices = nil;
    [super dealloc];
}

@end

@implementation MPSurveyTextQuestion

@end
