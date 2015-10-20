//
//  SettingsViewControllerTableViewController.h
//  SampleApp
//
//

#import <UIKit/UIKit.h>
#import <AloomaIos/Alooma.h>

@protocol SettingsDelegate <NSObject>

@required
- (void)statusChanged:(NSString*)status;

@end

@interface SettingsViewControllerTableViewController : UITableViewController

@property (nonatomic, weak) id<SettingsDelegate> delegate;

- (void)sendEvent;
- (void)flushEvents;

@end
