//
//  GFSViewController.m
//  Convolver
//
//  Created by Bill Dudney on 3/19/12.
//  Copyright (c) 2012 Gala Factory Software, LLC. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "GFSConvolvedViewController.h"
#import "GFSImageConvolver.h"
#import "GFSImageSeparator.h"

@interface GFSConvolvedViewController ()

@property(nonatomic, strong) UIImage *originalImage;
@property(nonatomic, strong) GFSImageConvolver *convolver;
@property(nonatomic, strong) GFSImageSeparator *separator;
@property(nonatomic, weak) IBOutlet UIImageView *imageView;
@property(nonatomic, weak) IBOutlet UIImageView *noiseImageView;
@property (weak, nonatomic) IBOutlet UILabel *divisorLabel;
@property(nonatomic, assign) BOOL displayingConvolvedImage;
@property(nonatomic, assign) NSUInteger tapCount;
@property (weak, nonatomic) IBOutlet UILabel *blendLabel;

@end

@implementation GFSConvolvedViewController

@synthesize originalImage = _originalImage;
@synthesize convolver = _convolver;
@synthesize separator = _separator;
@synthesize imageView = _imageView;
@synthesize noiseImageView = _noiseImage;
@synthesize divisorLabel = _multiplierLayer;
@synthesize displayingConvolvedImage = _displayingConvolvedImage;
@synthesize tapCount = _tapCount;
@synthesize blendLabel = _blendLabel;

- (IBAction)edgeDetection:(id)sender {
  short edgeDetectionKernel[] = {
    -1.0, -1.0, -1.0,
    -1.0,  8.0, -1.0,
    -1.0, -1.0, -1.0
  };
  [self.convolver setKernel:edgeDetectionKernel width:3 height:3];
  self.imageView.image = [UIImage imageWithCGImage:(__bridge CGImageRef)self.convolver.convolvedImage];
}

- (IBAction)blur:(id)sender {
  short blurKernel[] = {
    0.0, 1.0, 0.0,
    1.0, 0.0, 1.0,
    0.0, 1.0, 0.0
  };
  [self.convolver setKernel:blurKernel width:3 height:3];
  self.imageView.image = [UIImage imageWithCGImage:(__bridge CGImageRef)self.convolver.convolvedImage];
}

- (IBAction)alpha:(id)sender {
  self.imageView.image = [UIImage imageWithCGImage:(__bridge CGImageRef)self.separator.alphaComponent];
}

- (IBAction)red:(id)sender {
  self.imageView.image = [UIImage imageWithCGImage:(__bridge CGImageRef)self.separator.redComponent];
}

- (IBAction)green:(id)sender {
  self.imageView.image = [UIImage imageWithCGImage:(__bridge CGImageRef)self.separator.greenComponent];
}

- (IBAction)blue:(id)sender {
  self.imageView.image = [UIImage imageWithCGImage:(__bridge CGImageRef)self.separator.blueComponent];
}

- (IBAction)sliderChanged:(UISlider *)sender {
  self.convolver.divsor = [sender value];
  self.divisorLabel.text = [NSString stringWithFormat:@"%d", self.convolver.divsor];
  self.imageView.image = [UIImage imageWithCGImage:(__bridge CGImageRef)self.convolver.convolvedImage];
}

- (void)handleGesture:(UIGestureRecognizer *)gestureRecognizer {
  if(self.displayingConvolvedImage) {
    self.imageView.image = self.originalImage;
  } else {
    self.imageView.image = [UIImage imageWithCGImage:(__bridge CGImageRef)self.convolver.convolvedImage];
  }
  self.displayingConvolvedImage = !self.displayingConvolvedImage;
}


- (void)blurredDoubleTapped:(UITapGestureRecognizer *)gr {
  self.noiseImageView.hidden = YES;
  self.blendLabel.hidden = YES;
}

- (void)handleDoubleTapGesture:(UITapGestureRecognizer *)gr {
  if(self.noiseImageView.hidden) {
    self.noiseImageView.hidden = NO;
    self.noiseImageView.hidden = NO;
  }
}

- (void)viewDidLoad {
  [super viewDidLoad];
  self.originalImage = [UIImage imageNamed:@"phillip.jpg"];
  UITapGestureRecognizer *tapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleGesture:)];
  [self.imageView addGestureRecognizer:tapGR];
  UITapGestureRecognizer *doubleTapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTapGesture:)];
  [tapGR requireGestureRecognizerToFail:doubleTapGR];
  [self.imageView addGestureRecognizer:doubleTapGR];
  
  NSURL *url = [[NSBundle mainBundle] URLForResource:@"phillip" withExtension:@"jpg"];
  self.separator = [[GFSImageSeparator alloc] initWithURL:url];
  self.convolver = [GFSImageConvolver imageConvolverForURL:url];
  self.imageView.image = [UIImage imageWithCGImage:(__bridge CGImageRef)self.convolver.convolvedImage];
  self.displayingConvolvedImage = YES;
  self.divisorLabel.text = @"1";

}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
  return YES;
}

- (void)viewDidUnload {
  [self setBlendLabel:nil];
  [super viewDidUnload];
}
@end