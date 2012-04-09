//
//  GFSNoiseGenerator.h
//  Convolver
//
//  Created by Bill Dudney on 4/6/12.
//  Copyright (c) 2012 Gala Factory Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GFSNoiseGenerator : NSObject

- (id)initWithSize:(CGSize)size octaves:(NSUInteger)octaveCount;

@property(nonatomic, assign) NSUInteger octaveCount;
@property(nonatomic, assign) CGSize size;

- (UIImage *)noiseImage;

@end
