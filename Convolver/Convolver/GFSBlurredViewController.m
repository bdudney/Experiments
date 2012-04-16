//
//  GFSBlurredViewController.m
//  Convolver
//
//  Created by Bill Dudney on 4/12/12.
//  Copyright (c) 2012 Gala Factory Software, LLC. All rights reserved.
//

#import "GFSBlurredViewController.h"
#import "GFSNoiseGenerator.h"

@interface GFSBlurredViewController ()

@property(nonatomic, strong) UIImage *originalImage;
@property(nonatomic, strong) GFSNoiseGenerator *noiseGenerator;
@property(nonatomic, assign) NSUInteger tapCount;

@property(nonatomic, weak) IBOutlet UIImageView *noiseImageView;
@property(nonatomic, weak) IBOutlet UILabel *blendLabel;

@end

@implementation GFSBlurredViewController

@synthesize originalImage = _originalImage;
@synthesize noiseGenerator = _noiseGenerator;
@synthesize tapCount = _tapCount;

@synthesize noiseImageView = _noiseImageView;
@synthesize blendLabel = _blendLabel;

- (void)viewDidLoad {
  [super viewDidLoad];
  self.originalImage = [UIImage imageNamed:@"phillip.jpg"];
  self.noiseGenerator = [[GFSNoiseGenerator alloc] initWithSize:CGSizeMake(512.0, 512.0) octaves:1];
  [self redoBlendedImage];
  
  UITapGestureRecognizer *blendedGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped:)];
  [self.noiseImageView addGestureRecognizer:blendedGR];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
  return UIInterfaceOrientationIsLandscape(interfaceOrientation);  
}

- (void)tapped:(UIGestureRecognizer *)gr {
  self.tapCount = 1 + self.tapCount;
  [self redoBlendedImage];
}

- (void)redoBlendedImage {
  UIImage *noiseImage = self.noiseGenerator.noiseImage;
  CGSize size = CGSizeMake(1024.0, 700.0);
  UIGraphicsBeginImageContextWithOptions(size, YES, 0.0);
  CGContextRef ctx = UIGraphicsGetCurrentContext();
  CGContextTranslateCTM(ctx, 0.0, size.height);
  CGContextScaleCTM(ctx, 1.0, -1.0);
  CGContextDrawImage(ctx, CGRectMake(0.0, 0.0, size.width, size.height), self.originalImage.CGImage);
  CGContextSetBlendMode(ctx, self.tapCount % 28);
  CGContextDrawImage(ctx, CGRectMake(0.0, 0.0, size.width, size.height), noiseImage.CGImage);
  CGImageRef blended = CGBitmapContextCreateImage(ctx);
  UIImage *blendedImage = [UIImage imageWithCGImage:blended];
  CGImageRelease(blended);
  UIGraphicsEndImageContext();
  
  self.noiseImageView.image = blendedImage;
  
  switch (self.tapCount % 28) {
    case kCGBlendModeNormal:
      self.blendLabel.text = @"Normal";
      break;
      
    case kCGBlendModeMultiply:
      self.blendLabel.text = @"Multiply";
      break;
      
    case kCGBlendModeScreen:
      self.blendLabel.text = @"Screen";
      break;
      
    case kCGBlendModeOverlay:
      self.blendLabel.text = @"Overlay";
      break;
      
    case kCGBlendModeDarken:
      self.blendLabel.text = @"Darken";
      break;
      
    case kCGBlendModeLighten:
      self.blendLabel.text = @"Lighten";
      break;
      
    case kCGBlendModeColorDodge:
      self.blendLabel.text = @"Color Dodge";
      break;
      
    case kCGBlendModeColorBurn:
      self.blendLabel.text = @"Color Burn";
      break;
      
    case kCGBlendModeSoftLight:
      self.blendLabel.text = @"Soft Light";
      break;
      
    case kCGBlendModeHardLight:
      self.blendLabel.text = @"Hard Light";
      break;
      
    case kCGBlendModeDifference:
      self.blendLabel.text = @"Difference";
      break;
      
    case kCGBlendModeExclusion:
      self.blendLabel.text = @"Exclusion";
      break;
      
    case kCGBlendModeHue:
      self.blendLabel.text = @"Hue";
      break;
      
    case kCGBlendModeSaturation:
      self.blendLabel.text = @"Saturation";
      break;
      
    case kCGBlendModeColor:
      self.blendLabel.text = @"Color";
      break;
      
    case kCGBlendModeLuminosity:
      self.blendLabel.text = @"Luminosity";
      break;
      
    case kCGBlendModeClear:
      self.blendLabel.text = @"Clear";
      break;
      
    case kCGBlendModeCopy:
      self.blendLabel.text = @"Copy";
      break;
      
    case kCGBlendModeSourceIn:
      self.blendLabel.text = @"Source In";
      break;
      
    case kCGBlendModeSourceOut:
      self.blendLabel.text = @"Source Out";
      break;
      
    case kCGBlendModeSourceAtop:
      self.blendLabel.text = @"Source Atop";
      break;
      
    case kCGBlendModeDestinationOver:
      self.blendLabel.text = @"Desitnation Over";
      break;
      
    case kCGBlendModeDestinationIn:
      
      self.blendLabel.text = @"Destination In";
      break;
      
    case kCGBlendModeDestinationOut:
      self.blendLabel.text = @"Destination Out";
      break;
      
    case kCGBlendModeDestinationAtop:
      self.blendLabel.text = @"Destination Atop";
      break;
      
    case kCGBlendModeXOR:
      self.blendLabel.text = @"XOR";
      break;
      
    case kCGBlendModePlusDarker:
      self.blendLabel.text = @"Plus Darker";
      break;
      
    case kCGBlendModePlusLighter:
      self.blendLabel.text = @"Plus Lighter";
      break;
      
    default:
      break;
  }
}

@end
