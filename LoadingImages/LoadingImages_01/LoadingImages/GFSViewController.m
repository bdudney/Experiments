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

- (void)viewDidLoad {
  [super viewDidLoad];
  self.imageView.image = [UIImage imageNamed:@"phillip.jpg"];
}

- (void)viewDidUnload {
  [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
  return YES;
}

@end
