//
//  SYArrayFilterTemplate.h
//  Shelley
//
//  Created by Pete Hodgson on 8/25/11.
//  Copyright 2011 ThoughtWorks. All rights reserved.
//

#import "Shelley.h"

//
//  SYFilter.h
//  Shelley
//
//  Created by Pete Hodgson on 7/17/11.
//  Copyright 2011 ThoughtWorks. All rights reserved.
//

@protocol SYFilter <NSObject>

- (void) setDoNotDescend:(BOOL)doNotDescend;
- (NSArray *) applyToViews:(NSArray *)views;
- (BOOL) nextFilterShouldNotDescend;

@end

@interface SYArrayFilterTemplate : NSObject<SYFilter> {
    
}

- (NSArray *) applyToView:(ShelleyView *)view;

@end
//
//  SYClassFilter.h
//  Shelley
//
//  Created by Pete Hodgson on 7/22/11.
//  Copyright 2011 ThoughtWorks. All rights reserved.
//


@interface SYClassFilter : SYArrayFilterTemplate {
    Class _targetClass;
	BOOL _includeSelf;
    BOOL _justFilter;
}
@property (readonly) Class target;

- (id)initWithClass:(Class)class;
- (id)initWithClass:(Class)class includeSelf:(BOOL)includeSelf;

@end

//
//  SYNthElementFilter.h
//  Shelley
//
//  Created by Pete Hodgson on 8/25/11.
//  Copyright 2011 ThoughtWorks. All rights reserved.
//


@interface SYNthElementFilter : NSObject<SYFilter> {
    NSUInteger _index;
}

@property (readonly) NSUInteger index; 

- (id)initWithIndex:(NSUInteger)index;

@end
//
//  SYParents.h
//  Shelley
//
//  Created by Pete Hodgson on 7/20/11.
//  Copyright 2011 ThoughtWorks. All rights reserved.
//

@interface SYParents : SYArrayFilterTemplate {
    
}

@end
//
//  SYPredicateFilter.h
//  Shelley
//
//  Created by Pete Hodgson on 7/20/11.
//  Copyright 2011 ThoughtWorks. All rights reserved.
//

@interface SYPredicateFilter : SYArrayFilterTemplate {
    SEL _selector;
    NSArray *_args;
    
}
@property (readonly) SEL selector;
@property (readonly) NSArray *args;

- (id)initWithSelector:(SEL)selector args:(NSArray *)args;

@end
