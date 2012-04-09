//
//  GFSVImageLoader.m
//  Convolver
//
//  Created by Bill Dudney on 3/24/12.
//  Copyright (c) 2012 Gala Factory Software, LLC. All rights reserved.
//

#import "GFSVImageLoader.h"

@interface GFSVImageLoader()

@property(nonatomic, assign, readwrite) CGSize imageSize;
@property(nonatomic, strong, readwrite) NSURL *originalImageURL;
@property(nonatomic, strong, readwrite) NSData *compliantData;

@end

@interface GFSVImageLoader(Private)

- (BOOL)loadCompliantImageData;

@end

@implementation GFSVImageLoader

@synthesize imageSize = _imageSize;
@synthesize originalImageURL = _originalImageURL;
@synthesize compliantData = _compliantData;


- (id)initWithURL:(NSURL *)orignalImageURL {
  self = [super init];
  if(nil != self) {
    self.originalImageURL = orignalImageURL;
    // load the image and get the vImage compliant data
    if(![self loadCompliantImageData]) {
      self = nil;
    }
  }
  return self;
  
}

- (id)initWithCompliantData:(NSData *)data imageSize:(CGSize)imageSize {
  self = [super init];
  if(nil != self) {
    self.compliantData = data;
    self.imageSize = imageSize;
  }
  return self;
}

@end

@implementation GFSVImageLoader(Private)

- (BOOL)loadCompliantImageData {
  BOOL success = NO;
  CGImageSourceRef imageSource = CGImageSourceCreateWithURL((__bridge CFURLRef)self.originalImageURL, NULL);
  if(NULL != imageSource) {
    CGImageRef imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
    if(NULL != imageRef) {
      self.imageSize = CGSizeMake(CGImageGetWidth(imageRef), CGImageGetHeight(imageRef));
      // this call is fine on iOS, but on the mac we'd want this to be
      // more careful to buidl the correct color sapce
      CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
      // this context conforms to the vImage requirments with alpha skip first
      CGContextRef conformantContext = CGBitmapContextCreate(NULL, self.imageSize.width, 
                                                             self.imageSize.height, 8, 
                                                             4 * self.imageSize.width, 
                                                             colorSpace,
                                                             kCGBitmapByteOrder32Big | kCGImageAlphaNoneSkipFirst);
      if(NULL != conformantContext) {
        CGContextDrawImage(conformantContext, CGRectMake(0., 0., self.imageSize.width, self.imageSize.height), imageRef);
        CGImageRef compliantImageRef = CGBitmapContextCreateImage(conformantContext);
        if(NULL != compliantImageRef) {
          CFDataRef dataRef = CGDataProviderCopyData(CGImageGetDataProvider(compliantImageRef));
          self.compliantData = (__bridge NSData *)dataRef;
          success = YES;
          CFRelease(dataRef);
        }
        CGImageRelease(compliantImageRef);
        CGContextRelease(conformantContext);
      }
      CGColorSpaceRelease(colorSpace);
      CGImageRelease(imageRef);
    }
    CFRelease(imageSource);
  }
  
  return success;
}

@end