//
//  CALayer+Pausable.m
//  LayerPausing
//
//  Created by Bill Dudney on 4/11/13.
//  Copyright (c) 2013 Bill Dudney. All rights reserved.
//

#import "CALayer+Pauseable.h"

@implementation CALayer (Pauseable)

- (void)updateAnimationSpeed:(CGFloat)speed {
  self.timeOffset = [self convertTime:CACurrentMediaTime() fromLayer:nil];
  self.beginTime = CACurrentMediaTime();
  self.speed = speed;
}

- (void)pauseAnimation {
  CFTimeInterval pausedTime = [self convertTime:CACurrentMediaTime()
                                      fromLayer:nil];
  self.speed = 0.0;
  self.timeOffset = pausedTime;
}

- (void)resumeAnimation {
  CFTimeInterval pausedTime = [self timeOffset];
  self.speed = 1.0;
  self.timeOffset = 0.0;
  self.beginTime = 0.0;
  CFTimeInterval timeSincePause = [self convertTime:CACurrentMediaTime()
                                          fromLayer:nil] - pausedTime;
  self.beginTime = timeSincePause;
}

@end
