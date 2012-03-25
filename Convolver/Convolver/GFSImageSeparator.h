//
//  GFSImageSeparator.h
//  Convolver
//
//  Created by Bill Dudney on 3/24/12.
//  Copyright (c) 2012 Gala Factory Software, LLC. All rights reserved.
//

#import "GFSVImageLoader.h"

/*
 * original image separated into A, R, G, B components
 */
@interface GFSImageSeparator : GFSVImageLoader

// CGImageRef in the DeviceGray color space
@property(nonatomic, readonly, strong) id alphaComponent;
// CGImageRef in the DeviceGray color space
@property(nonatomic, readonly, strong) id redComponent;
// CGImageRef in the DeviceGray color space
@property(nonatomic, readonly, strong) id greenComponent;
// CGImageRef in the DeviceGray color space
@property(nonatomic, readonly, strong) id blueComponent;

@end
