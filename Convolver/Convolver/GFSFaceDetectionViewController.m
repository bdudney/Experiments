//
//  GFSFaceDetectionViewController.m
//  Convolver
//
//  Created by Bill Dudney on 4/14/12.
//  Copyright (c) 2012 Gala Factory Software, LLC. All rights reserved.
//

#import "GFSFaceDetectionViewController.h"
#import <CoreImage/CoreImage.h>

@interface GFSFaceDetectionViewController ()

@property (nonatomic, weak) IBOutlet UIImageView *imageView;

@end

@implementation GFSFaceDetectionViewController

@synthesize imageView = _imageView;

- (void)viewDidLoad {
  [super viewDidLoad];
  CIImage* image = [CIImage imageWithCGImage:[self.imageView.image CGImage]];
  NSDictionary *options = [NSDictionary dictionaryWithObject:CIDetectorAccuracyHigh
                                                      forKey:CIDetectorAccuracy];
  CIDetector* detector = [CIDetector detectorOfType:CIDetectorTypeFace
                                            context:nil
                                            options:options];
  NSLog(@"features = %@", [[detector featuresInImage:image] valueForKeyPath:@"bounds"]);
}

- (void)viewDidUnload {
  [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
  return YES;
}

@end
