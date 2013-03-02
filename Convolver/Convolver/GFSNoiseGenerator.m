//
//  GFSNoiseGenerator.m
//  Convolver
//
//  Created by Bill Dudney on 4/6/12.
//  Copyright (c) 2012 Gala Factory Software, LLC. All rights reserved.
//

#import "GFSNoiseGenerator.h"
#import "GFSVImageLoader.h"
#import "GFSImageConvolver.h"

@interface GFSNoiseGenerator()

@property(nonatomic, strong) NSData *baseNoise;
@property(nonatomic, strong) GFSImageConvolver *horizontalConvolver;
@property(nonatomic, strong) GFSImageConvolver *verticalConvolver;
@property(nonatomic, strong) UIImage *bluredImage;

@end

@interface GFSNoiseGenerator(Private)

@end

@implementation GFSNoiseGenerator

@synthesize horizontalConvolver = _horizontalConvolver;
@synthesize verticalConvolver = _verticalConvolver;
@synthesize baseNoise = _baseNoise;
@synthesize bluredImage = _bluredImage;
@synthesize octaveCount = _octaveCount;
@synthesize size = _size;

- (id)initWithSize:(CGSize)size octaves:(NSUInteger)octaveCount {
  self = [super init];
  if(nil != self) {
    self.size = size;
    self.octaveCount = octaveCount;
  }
  return self;
}

typedef struct GFSConvolverLumance { // this order only works for big endian
uint8_t a;
uint8_t l;
} GFSConvolverLumance;


- (NSData *)baseLANoise {
  if(nil == _baseNoise) {
    NSUInteger count = self.size.width * self.size.height;
    GFSConvolverLumance *colors = (GFSConvolverLumance *)calloc(count, sizeof(GFSConvolverLumance));
    srandomdev();
    for(NSUInteger i = 0;i < count;i++) {
      uint8_t value = random() % 256;
      colors[i].l = value;
      colors[i].a = 255;
    }
    self.baseNoise = [NSData dataWithBytesNoCopy:(void *)colors
                                          length:sizeof(GFSConvolverLumance) * count
                                    freeWhenDone:YES];
  }
  return _baseNoise;
}

- (NSData *)baseRGBANoise {
  if(nil == _baseNoise) {
    NSUInteger count = self.size.width * self.size.height;
    GFSConvolverColor *colors = (GFSConvolverColor *)calloc(count, sizeof(GFSConvolverColor));
    srandomdev();
    for(NSUInteger i = 0;i < count;i++) {
      uint8_t value = random() % 256;
      colors[i].r = value;
      colors[i].g = value;
      colors[i].b = value;
      colors[i].a = 255;
    }
    self.baseNoise = [NSData dataWithBytesNoCopy:(void *)colors
                                          length:sizeof(GFSConvolverColor) * count
                                    freeWhenDone:YES];
  }
  return _baseNoise;
}

- (NSData *)baseNoise {
  if(nil == _baseNoise) {
    self.baseNoise = [self baseRGBANoise];
  }
  return _baseNoise;
}

- (NSArray *)noiseImages {
  return nil;
}

- (GFSImageConvolver *)horizontalConvolver {
  if(nil == _horizontalConvolver) {
    self.horizontalConvolver = [[GFSImageConvolver alloc] initWithImageData:self.baseNoise imageSize:self.size];
    
    short *motionBlurKernel = calloc(25, sizeof(short));
    for(int i = 0;i < 25;i++) {
      motionBlurKernel[i] = 1.0;
    }
    [self.horizontalConvolver setKernel:motionBlurKernel width:25 height:1];
    self.horizontalConvolver.divsor = 25;
  }
  return _horizontalConvolver;
}

- (GFSImageConvolver *)verticalConvolver {
  if(nil == _verticalConvolver) {
    self.verticalConvolver = [[GFSImageConvolver alloc] initWithImageData:self.baseNoise imageSize:self.size];
    
    short *motionBlurKernel = calloc(25, sizeof(short));
    for(int i = 0;i < 25;i++) {
      motionBlurKernel[i] = 1.0;
    }
    [self.verticalConvolver setKernel:motionBlurKernel width:1 height:25];
    self.verticalConvolver.divsor = 25;
  }
  return _verticalConvolver;
}

- (UIImage *)noiseImage {
  if(nil == self.bluredImage) {
    UIGraphicsBeginImageContext(self.size);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(ctx, [[UIColor whiteColor] CGColor]);
    CGRect rect = CGRectMake(0.0, 0.0, self.size.width, self.size.height);
    CGContextFillRect(ctx, rect);
    CGContextSetBlendMode(ctx, kCGBlendModeMultiply);
    CGContextDrawImage(ctx, rect, (__bridge CGImageRef)self.horizontalConvolver.convolvedImage);
    CGContextDrawImage(ctx, rect, (__bridge CGImageRef)self.verticalConvolver.convolvedImage);
    self.bluredImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
  }
  return _bluredImage;
}

@end


@implementation GFSNoiseGenerator(Private)

@end