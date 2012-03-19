//
//  GFSViewController.m
//  DrawingImages
//
//  Created by Bill Dudney on 2/2/12.
//  Copyright (c) 2012 Gala Factory Software, LLC. All rights reserved.
//

#import "GFSViewController.h"
#import <ImageIO/ImageIO.h>

@interface GFSViewController ()

@property(nonatomic, weak) IBOutlet UIImageView *imageView;

@end

@implementation GFSViewController

@synthesize imageView = _imageView;

-(UIImage *)thumbnailImage {
  UIImage *image = nil;
  NSString *path = [[NSBundle mainBundle] pathForResource:@"phillip"
                                                   ofType:@"jpg"];
  NSURL *url = [NSURL fileURLWithPath:path];
  CGImageSourceRef imageSource = 
  CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);
  if(NULL == imageSource) {
    NSLog(@"failed to image source for %@", path);
  } else {
    NSNumber *maxWidth = [NSNumber numberWithInteger:1024];
    id maxWidthKey = (__bridge id)kCGImageSourceThumbnailMaxPixelSize;
    NSNumber *always = [NSNumber numberWithBool:YES];
    id alwaysKey = (__bridge id)kCGImageSourceCreateThumbnailFromImageAlways;
    NSNumber *transform = [NSNumber numberWithBool:YES];
    id transformKey = (__bridge id)kCGImageSourceCreateThumbnailWithTransform;
    NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                maxWidth, maxWidthKey,
                                always, alwaysKey,
                                transform, transformKey,
                                nil];
    CGImageRef cgImage = 
    CGImageSourceCreateThumbnailAtIndex(imageSource, 0,
                                        (__bridge CFDictionaryRef)dictionary);
    image = [UIImage imageWithCGImage:cgImage];
    CFRelease(imageSource);
    CGImageRelease(cgImage);
  }
  return image;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  self.imageView.image = [self thumbnailImage];
}

- (void)viewDidUnload {
  [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
  return YES;
}

@end
