//
//  GFSDefaultImageViewController.m
//  Convolver
//
//  Created by Bill Dudney on 4/12/12.
//  Copyright (c) 2012 Gala Factory Software, LLC. All rights reserved.
//

#import "GFSDefaultImageViewController.h"

@interface GFSDefaultImageViewController ()

@end

@implementation GFSDefaultImageViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
  return UIInterfaceOrientationIsLandscape(interfaceOrientation);  
}

@end
