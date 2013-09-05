#import "MPSurvey.h"
#import "MPSurveyQuestion.h"

@interface MPSurvey ()

@property (nonatomic) NSUInteger ID;
@property (nonatomic) NSUInteger collectionID;
@property (nonatomic, retain) NSArray *questions;

- (id)initWithID:(NSUInteger *)ID collectionID:(NSUInteger *)collectionID andQuestions:(NSArray *)questions;

@end

@implementation MPSurvey

+ (MPSurvey *)surveyWithJSONObject:(NSDictionary *)object
{
    if (object == nil) {
        NSLog(@"survey json object should not be nil");
        return nil;
    }
    NSNumber *ID = object[@"id"];
    if (!([ID isKindOfClass:[NSNumber class]] && [ID integerValue] > 0)) {
        NSLog(@"invalid survey id: %@", ID);
        return nil;
    }
    NSArray *collections = object[@"collections"];
    if (!([collections isKindOfClass:[NSArray class]] && [collections count] > 0)) {
        NSLog(@"invalid survey collections: %@", collections);
        return nil;
    }
    NSDictionary *collection = collections[0];
    if (![collection isKindOfClass:[NSDictionary class]]) {
        NSLog(@"invalid survey collection: %@", collection);
        return nil;
    }
    NSNumber *collectionID = collection[@"id"];
    if (!([collectionID isKindOfClass:[NSNumber class]] && [collectionID integerValue] > 0)) {
        NSLog(@"invalid survey collection id: %@", collectionID);
        return nil;
    }
    NSMutableArray *questions = [NSMutableArray array];
    for (NSDictionary *question in object[@"questions"]) {
        MPSurveyQuestion *q = [MPSurveyQuestion questionWithJSONObject:question];
        if (q) {
            [questions addObject:q];
        }
    }
    return [[[MPSurvey alloc] initWithID:[ID unsignedIntegerValue]
                            collectionID:[collectionID unsignedIntegerValue]
                            andQuestions:[NSArray arrayWithArray:questions]] autorelease];
}

- (id)initWithID:(NSUInteger *)ID collectionID:(NSUInteger *)collectionID andQuestions:(NSArray *)questions
{
    if (questions != nil && [questions count] > 0) {
        if (self = [super init]) {
            _ID = ID;
            _collectionID = collectionID;
            self.questions = questions;
        }
    } else {
        NSLog(@"survey has no questions: %@", questions);
    }
    return self;
}

- (void)dealloc
{
    _ID = nil;
    _collectionID = nil;
    self.questions = nil;
    [super dealloc];
}

@end
