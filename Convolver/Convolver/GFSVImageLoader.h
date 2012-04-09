//
//  GFSVImageLoader.h
//  Convolver
//
//  Created by Bill Dudney on 3/24/12.
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

#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>

// this is just a debugging struct to look at the argb colors
// coming back from the convolution, not currently used, but you
// can debug like this
// GFSConvolverColor *color = (GFSConvolveColor *)outData;
// then loop through color looking at color values thusly
// for...
//  printf("r = %d", color[i].r)
// ...
typedef struct GFSConvolverColor { // this order only works for big endian
  uint8_t a;
  uint8_t r;
  uint8_t g;
  uint8_t b;
} GFSConvolverColor;

@interface GFSVImageLoader : NSObject

- (id)initWithURL:(NSURL *)orignalImageURL;
- (id)initWithCompliantData:(NSData *)data imageSize:(CGSize)imageSize;

@property(nonatomic, strong, readonly) NSURL *originalImageURL;
@property(nonatomic, strong, readonly) NSData *compliantData;
@property(nonatomic, assign, readonly) CGSize imageSize;

@end
