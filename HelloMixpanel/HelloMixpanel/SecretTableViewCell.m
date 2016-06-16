//
//  SecretTableViewCell.m
//  HelloMixpanel
//
//  Created by Alex Hofsteede on 12/5/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//

#import "SecretTableViewCell.h"

@implementation SecretTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)awakeFromNib
{
    // Initialization code
    [super awakeFromNib];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
