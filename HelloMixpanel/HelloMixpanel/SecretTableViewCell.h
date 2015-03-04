//
//  SecretTableViewCell.h
//  HelloMixpanel
//
//  Created by Alex Hofsteede on 12/5/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SecretTableViewCell : UITableViewCell

@property (nonatomic, strong) IBOutlet UILabel *contentLabel;
@property (nonatomic, strong) IBOutlet UILabel *locationLabel;
@property (nonatomic, strong) IBOutlet UILabel *likeslabel;
@property (nonatomic, strong) IBOutlet UILabel *commentsLabel;
@property (nonatomic, strong) IBOutlet UIImageView *backgroundImage;

@end
