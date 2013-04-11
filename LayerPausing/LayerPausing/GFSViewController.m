//
//  GFSViewController.m
//  LayerPausing
//
//  Created by Bill Dudney on 4/11/13.
//  Copyright (c) 2013 Bill Dudney. All rights reserved.
//

#import "GFSViewController.h"
#import "CALayer+Pauseable.h"

@interface GFSViewController ()

@property (weak, nonatomic) IBOutlet UIView *movingView;

@end

@implementation GFSViewController

- (IBAction)changeSpeed:(UISlider *)sender {
  [self.movingView.layer updateAnimationSpeed:[sender value]];
}

- (IBAction)resumeAnimation:(id)sender {
  [self.movingView.layer resumeAnimation];
}

- (IBAction)pauseAnimations:(id)sender {
  [self.movingView.layer pauseAnimation];
}

- (IBAction)moveView:(UITapGestureRecognizer *)tapGR {
  [UIView animateWithDuration:10.0
                   animations:^{
                     self.movingView.center = [tapGR locationInView:self.view];
                   }];
}

@end
