//
//  GFSImageConvolver.h
//  DrawingImages
//
//  Created by Bill Dudney on 3/18/12.
//  Copyright (c) 2012 Gala Factory Software, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <ImageIO/ImageIO.h>

// this is just a debugging struct to look at the argb colors
// coming back from the convlution, not currently used, but you
// can debug like this
// GFSConvolverColor *color = (GFSConvolveColor *)outData;
// then loop through color looking at color values thusly
// for...
//  printf("r = %d", color[i].r)
// ...
typedef struct GFSConvolverColor {
  uint8_t a;
  uint8_t r;
  uint8_t g;
  uint8_t b;
} GFSConvolverColor;

@interface GFSImageConvolver : NSObject

+ (id)imageConvolverForURL:(NSURL *)originalImageURL;

- (id)initWithURL:(NSURL *)orignalImageURL;

// memcopy the values into a new array of widthxheight shorts
- (void)setKernel:(short *)values width:(short)width height:(short)height;

@property(nonatomic, assign) int32_t divsor;
@property(nonatomic, assign) GFSConvolverColor backgroundColor;

// really a CGImageRef but since we can't have a strong relationship
// with a CGImageRef marking it id, memory managed with CGImageRelease/Retain
@property(nonatomic, readonly, strong) id convolvedImage;

@end
