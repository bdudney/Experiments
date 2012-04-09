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

@property(nonatomic, assign) short kernelWidth;
@property(nonatomic, assign) short kernelHeight;

@end

@interface GFSImageConvolver(Private)

- (void)releaseConvolvedImage;

@end

@implementation GFSImageConvolver {
  short *_kernel;
}

@synthesize divsor = _divsor;
@synthesize backgroundColor = _backgroundColor;
@synthesize convolvedImage = _convolvedImage;
@synthesize kernelWidth = _kernelWidth;
@synthesize kernelHeight = _kernelHeight;

+ (id)imageConvolverForURL:(NSURL *)originalImageURL {
  return [[self alloc] initWithURL:originalImageURL];
}

- (id)initWithURL:(NSURL *)orignalImageURL {
  self = [super initWithURL:orignalImageURL];
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
  }
  return self;
  
}

- (id)initWithImageData:(NSData *)data imageSize:(CGSize)imageSize {
  self = [super initWithCompliantData:data imageSize:imageSize];
  if(nil != self) {
    short blurKernel[] = {
      1.0, 1.0, 1.0, 
      1.0, 1.0, 1.0,
      1.0, 1.0, 1.0
    };
    [self setKernel:blurKernel width:3 height:3];
    // default to black background
    self.backgroundColor = (GFSConvolverColor){0,0,0,0};
    self.divsor = 81;
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
                                                   kCGBitmapByteOrder32Big | kCGImageAlphaNoneSkipFirst,
                                                   dataProviderRef,
                                                   NULL, NO, kCGRenderingIntentDefault);
      CGDataProviderRelease(dataProviderRef);
      CGColorSpaceRelease(colorSpace);
    }
  }
  return _convolvedImage;
}

@end


@implementation GFSImageConvolver (Private)

- (void)releaseConvolvedImage {
  if(nil != _convolvedImage) {
    CGImageRelease((__bridge CGImageRef)_convolvedImage);
    _convolvedImage = nil;
  }
}

@end