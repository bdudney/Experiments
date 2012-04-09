//
//  GFSImageConvolver.h
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

#import "GFSVImageLoader.h"

/*
 * Use vImage to apply convolution filters to images.
 *
 * Create a new Image Convolver with a URL to an original image. Modify the
 * parameters as desired (kernel, background color, divisor).
 *
 * The result of convolvedImage is cached and not recomputed unless one or more
 * of the parameters is changed.
 *
 * The original data is also cached in the vImage format.
 *
 * Stuff to do:
 *  - break the ARGB data into planar data for each component
 *  - allow multiple convolutions to be chained
 *  - provide a means to specify a ROI in the original image
 *  - build a means to compare performance of this approach vs OpenGL shaders
 *   - memory usage
 *   - wall time for various convolutions
 *   - performance as images get larger, esp beyond what will fit in a texture
 */
@interface GFSImageConvolver : GFSVImageLoader

+ (id)imageConvolverForURL:(NSURL *)originalImageURL;

- (id)initWithURL:(NSURL *)orignalImageURL;

- (id)initWithImageData:(NSData *)data imageSize:(CGSize)imageSize;

// memcopy the values into a new array of widthxheight shorts
- (void)setKernel:(short *)values width:(short)width height:(short)height;

@property(nonatomic, assign) int32_t divsor;
@property(nonatomic, assign) GFSConvolverColor backgroundColor;

// really a CGImageRef but since we can't have a strong relationship
// with a CGImageRef marking it id, memory managed with CGImageRelease/Retain
@property(nonatomic, readonly, strong) id convolvedImage;

@end
