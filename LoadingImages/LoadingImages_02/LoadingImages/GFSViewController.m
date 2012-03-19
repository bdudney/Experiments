//
//  GFSViewController.m
//  DrawingImages
//
//  Created by Bill Dudney on 2/2/12.
//  Copyright (c) 2012 Gala Factory Software, LLC. All rights reserved.
//

#import "GFSViewController.h"

@interface GFSViewController ()

@property(nonatomic, weak) IBOutlet UIImageView *imageView;

@end

@implementation GFSViewController

@synthesize imageView = _imageView;

-(UIImage *)redrawnImage {
  NSString *path = [[NSBundle mainBundle] pathForResource:@"phillip" ofType:@"jpg"];
  UIImage *image = [UIImage imageWithContentsOfFile:path];
  UIGraphicsBeginImageContextWithOptions(CGSizeMake(1024.0, 768.0), YES, 0.0);
  [image drawInRect:CGRectMake(0.0, 0.0, 1024.0, 768.0)];
  UIImage *redrawnImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  return redrawnImage;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  self.imageView.image = [self redrawnImage];
}

- (void)viewDidUnload {
  [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
  return YES;
}

@end
