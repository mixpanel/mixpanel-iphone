//
//  MixpanelAPI_Private.h
//  MPLib
//

#import "MixpanelAPI.h"

@interface MixpanelAPI ()

@property(nonatomic,copy) NSString *apiToken;
@property(nonatomic,retain) NSMutableDictionary *superProperties;
@property(nonatomic,retain) NSArray *eventsToSend;
@property(nonatomic,retain) NSArray *peopleToSend;
@property(nonatomic,retain) NSMutableArray *eventQueue;
@property(nonatomic,retain) NSMutableArray *peopleQueue;
@property(nonatomic,retain) NSURLConnection *connection;
@property(nonatomic,retain) NSURLConnection *peopleConnection;
@property(nonatomic,retain) NSMutableData *responseData;
@property(nonatomic,retain) NSMutableData *peopleResponseData;
@property(nonatomic,retain) NSString *defaultUserId;

-(NSString*)encodedStringFromArray:(NSArray*)array;
-(void)flush;
-(void)unarchiveData;
-(void)unarchiveEvents;
-(void)unarchivePeople;
-(void)archiveData;
-(void)archiveEvents;
-(void)archivePeople;
-(void)applicationWillTerminate:(NSNotification *)notification;
-(void)applicationWillEnterForeground:(NSNotificationCenter *)notification;
-(void)applicationDidEnterBackground:(NSNotificationCenter *)notification;

@end
