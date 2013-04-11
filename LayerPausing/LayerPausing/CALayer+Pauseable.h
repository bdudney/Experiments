//
//  CALayer+Pausable.h
//  LayerPausing
//
//  Created by Bill Dudney on 4/11/13.
//  Copyright (c) 2013 Bill Dudney. All rights reserved.
//
#import <QuartzCore/QuartzCore.h>

@interface CALayer (Pauseable)

- (void)updateAnimationSpeed:(CGFloat)speed;
- (void)pauseAnimation;
- (void)resumeAnimation;

@end
