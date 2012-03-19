//
//  GFSViewController.m
//  Convolver
//
//  Created by Bill Dudney on 3/19/12.
//  Copyright (c) 2012 Gala Factory Software, LLC. All rights reserved.
//

#import "GFSViewController.h"
#import "GFSImageConvolver.h"

@interface GFSViewController ()

@property(nonatomic, strong) UIImage *originalImage;
@property(nonatomic, strong) GFSImageConvolver *convolver;
@property(nonatomic, weak) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UILabel *divisorLabel;
@property(nonatomic, assign) BOOL displayingConvolvedImage;

@end

@implementation GFSViewController

@synthesize originalImage = _originalImage;
@synthesize convolver = _convolver;
@synthesize imageView = _imageView;
@synthesize divisorLabel = _multiplierLayer;
@synthesize displayingConvolvedImage = _displayingConvolvedImage;

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

- (void)viewDidLoad {
  [super viewDidLoad];
  self.originalImage = [UIImage imageNamed:@"phillip.jpg"];
  UITapGestureRecognizer *tapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleGesture:)];
  [self.imageView addGestureRecognizer:tapGR];
  
  NSURL *url = [[NSBundle mainBundle] URLForResource:@"phillip" withExtension:@"jpg"];
  self.convolver = [GFSImageConvolver imageConvolverForURL:url];
  self.imageView.image = [UIImage imageWithCGImage:(__bridge CGImageRef)self.convolver.convolvedImage];
  self.displayingConvolvedImage = YES;
  self.divisorLabel.text = @"1";
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
  return YES;
}

@end