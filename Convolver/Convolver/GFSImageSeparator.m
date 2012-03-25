//
//  GFSImageSeparator.m
//  Convolver
//
//  Created by Bill Dudney on 3/24/12.
//  Copyright (c) 2012 Gala Factory Software, LLC. All rights reserved.
//

#import "GFSImageSeparator.h"
#import <Accelerate/Accelerate.h>


@interface GFSImageSeparator(Private)

- (id)newImageFromData:(void *)ptr;
- (void)separateComponents;

@end

@implementation GFSImageSeparator

@synthesize alphaComponent = _alphaComponent;
@synthesize redComponent = _redComponent;
@synthesize greenComponent = _greenComponent;
@synthesize blueComponent = _blueComponent;

- (id)alphaComponent {
  if(nil == _alphaComponent) {
    [self separateComponents];
  }
  return _alphaComponent;
}

- (id)redComponent {
  if(nil == _redComponent) {
    [self separateComponents];
  }
  return _redComponent;
}

- (id)greenComponent {
  if(nil == _greenComponent) {
    [self separateComponents];
  }
  return _greenComponent;
}

- (id)blueComponent {
  if(nil == _blueComponent) {
    [self separateComponents];
  }
  return _blueComponent;
}

@end

@implementation GFSImageSeparator(Private)

- (void)separateComponents {
  vImage_Buffer src = { (void *)[self.compliantData bytes],
    self.imageSize.height,
    self.imageSize.width,
    self.imageSize.width * 4};
  void *alphaData = malloc(self.imageSize.width * self.imageSize.height);
  vImage_Buffer alpha = { alphaData,
    self.imageSize.height,
    self.imageSize.width,
    self.imageSize.width };
  void *redData = malloc(self.imageSize.width * self.imageSize.height);
  vImage_Buffer red = { redData,
    self.imageSize.height,
    self.imageSize.width,
    self.imageSize.width };
  void *greenData = malloc(self.imageSize.width * self.imageSize.height);
  vImage_Buffer green = { greenData,
    self.imageSize.height,
    self.imageSize.width,
    self.imageSize.width };
  void *blueData = malloc(self.imageSize.width * self.imageSize.height);
  vImage_Buffer blue = { blueData,
    self.imageSize.height,
    self.imageSize.width,
    self.imageSize.width };
  vImage_Error err = vImageConvert_ARGB8888toPlanar8(&src, &alpha, &red, &green, &blue, kvImageNoFlags);
  
  if(err == kvImageNoError) {
    if(NULL != _alphaComponent) {
      CGImageRelease((__bridge CGImageRef)_alphaComponent);
    }
    if(NULL != _redComponent) {
      CGImageRelease((__bridge CGImageRef)_redComponent);
    }
    if(NULL != _greenComponent) {
      CGImageRelease((__bridge CGImageRef)_greenComponent);
    }
    if(NULL != _blueComponent) {
      CGImageRelease((__bridge CGImageRef)_blueComponent);
    }
    _alphaComponent = [self newImageFromData:alphaData];
    _redComponent = [self newImageFromData:redData];
    _blueComponent = [self newImageFromData:blueData];
    _greenComponent = [self newImageFromData:greenData];    
  }
}

- (id)newImageFromData:(void *)ptr {
  NSData *data = [NSData dataWithBytesNoCopy:ptr
                                      length:self.imageSize.width * self.imageSize.height];
  CGDataProviderRef dataProviderRef = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
  // divice RGB is fine for iOS but for the Mac we'd want to be more creative
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
  id image = (__bridge id)CGImageCreate(self.imageSize.width, self.imageSize.height,
                                        8, 8, self.imageSize.width,
                                        colorSpace,
                                        kCGBitmapByteOrder32Big | kCGImageAlphaNone,
                                        dataProviderRef,
                                        NULL, NO, kCGRenderingIntentDefault);
  CGDataProviderRelease(dataProviderRef);
  CGColorSpaceRelease(colorSpace);
  return image;
}

@end