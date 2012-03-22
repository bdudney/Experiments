//
//  GFSImageConvolver.m
//  DrawingImages
//
//  Created by Bill Dudney on 3/18/12.
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

#import "GFSImageConvolver.h"
#import <Accelerate/Accelerate.h>

@interface GFSImageConvolver()

@property(nonatomic, assign) CGSize imageSize;
@property(nonatomic, assign) short kernelWidth;
@property(nonatomic, assign) short kernelHeight;
@property(nonatomic, strong) NSURL *originalImageURL;
@property(nonatomic, strong) NSData *compliantData;

@end

@interface GFSImageConvolver(Private)

- (BOOL)loadCompliantImageData;
- (void)releaseConvolvedImage;

@end

@implementation GFSImageConvolver {
  short *_kernel;
}

@synthesize divsor = _divsor;
@synthesize backgroundColor = _backgroundColor;
@synthesize convolvedImage = _convolvedImage;
@synthesize imageSize = _imageSize;
@synthesize kernelWidth = _kernelWidth;
@synthesize kernelHeight = _kernelHeight;
@synthesize originalImageURL = _originalImageURL;
@synthesize compliantData = _compliantData;

+ (id)imageConvolverForURL:(NSURL *)originalImageURL {
  return [[self alloc] initWithURL:originalImageURL];
}

- (id)initWithURL:(NSURL *)orignalImageURL {
  self = [super init];
  if(nil != self) {
    short edgeDetectionKernel[] = {
      -1.0, -1.0, -1.0,
      -1.0,  8.0, -1.0,
      -1.0, -1.0, -1.0
    };
    [self setKernel:edgeDetectionKernel width:3 height:3];
    // default to black background
    self.backgroundColor = (GFSConvolverColor){0,0,0,0};
    self.divsor = 1;
    self.originalImageURL = orignalImageURL;
    // load the image and get the vImage compliant data
    if(![self loadCompliantImageData]) {
      self = nil;
    }
  }
  return self;
  
}

// memcopy the values into a new array of widthxheight shorts
- (void)setKernel:(short *)values width:(short)width height:(short)height {
  short *newKernel = calloc(height * width, sizeof(short));
  if(NULL != newKernel) {
    if(NULL != _kernel) {
      free(_kernel);
    }
    memcpy(newKernel, values, width * height * sizeof(short));
    _kernel = newKernel;
    self.kernelWidth = width;
    self.kernelHeight = height;
    [self releaseConvolvedImage];
  }
}

- (void)setDivsor:(int32_t)divsor {
  _divsor = divsor;
  [self releaseConvolvedImage];
}

- (void)setBackgroundColor:(GFSConvolverColor)backgroundColor {
  _backgroundColor = backgroundColor;
  [self releaseConvolvedImage];
}

- (id)convolvedImage {
  if(nil == _convolvedImage) {
    vImage_Buffer src = { (void *)[self.compliantData bytes],
      self.imageSize.height,
      self.imageSize.width,
      self.imageSize.width * 4};
    void *outData = malloc([self.compliantData length]);
    vImage_Buffer dest = { outData,
      self.imageSize.height,
      self.imageSize.width,
      self.imageSize.width * 4};
    
    vImage_Error err = vImageConvolve_ARGB8888(&src, &dest, NULL, 0, 0,
                                               _kernel, self.kernelWidth, self.kernelHeight, 
                                               self.divsor,
                                               (uint8_t *)&_backgroundColor,
                                               kvImageBackgroundColorFill);
    if(err == kvImageNoError) {
      NSData *destData = [NSData dataWithBytesNoCopy:dest.data
                                              length:[self.compliantData length]];
      CGDataProviderRef dataProviderRef = CGDataProviderCreateWithCFData((__bridge CFDataRef)destData);
      // divice RGB is fine for iOS but for the Mac we'd want to be more creative
      CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
      _convolvedImage = (__bridge id)CGImageCreate(self.imageSize.width, self.imageSize.height,
                                                   8, 8 * 4, self.imageSize.width * 4,
                                                   colorSpace,
                                                   kCGBitmapByteOrder32Host | kCGImageAlphaNoneSkipFirst,
                                                   dataProviderRef,
                                                   NULL, NO, kCGRenderingIntentDefault);
      CGDataProviderRelease(dataProviderRef);
      CGColorSpaceRelease(colorSpace);
    }
  }
  return _convolvedImage;
}

@end

@implementation GFSImageConvolver(Private)

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
                                                             kCGBitmapByteOrder32Host | kCGImageAlphaNoneSkipFirst);
      if(NULL != conformantContext) {
        CGContextDrawImage(conformantContext, CGRectMake(0., 0., self.imageSize.width, self.imageSize.height), imageRef);
        CGImageRef conformantImage = CGBitmapContextCreateImage(conformantContext);
        if(NULL != conformantImage) {
          CFDataRef dataRef = CGDataProviderCopyData(CGImageGetDataProvider(conformantImage));
          self.compliantData = (__bridge NSData *)dataRef;
          success = YES;
          CFRelease(dataRef);
        }
        CGImageRelease(conformantImage);
        CGContextRelease(conformantContext);
      }
      CGColorSpaceRelease(colorSpace);
      CGImageRelease(imageRef);
    }
    CFRelease(imageSource);
  }
  
  return success;
}

- (void)releaseConvolvedImage {
  if(nil != _convolvedImage) {
    CGImageRelease((__bridge CGImageRef)_convolvedImage);
    _convolvedImage = nil;
  }
}

@end