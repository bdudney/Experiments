//
//  GFSViewController.m
//  ImageDecompress
//
//  Created by Bill Dudney on 4/12/13.
//  Copyright (c) 2013 Bill Dudney. All rights reserved.
//

#import "GFSViewController.h"

typedef void(^ImageDecompressCompletion)(UIImage *decompressedImage);

@interface GFSViewController ()

@property (weak, nonatomic) IBOutlet UIImageView *imageView;

@end

@implementation GFSViewController

+ (NSOperationQueue *)decompressionQueue {
  static NSOperationQueue *queue = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    queue = [[NSOperationQueue alloc] init];
  });
  return queue;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  [self decompressImage:@"IMG_4087" extension:@"jpg"
             completion:^(UIImage *decompressedImage) {
               self.imageView.image = decompressedImage;
             }];
}

- (void)decompressImage:(NSString *)name
              extension:(NSString *)extension
             completion:(ImageDecompressCompletion)completionBlock {
  [[[self class] decompressionQueue] addOperationWithBlock:^{
    // create a graphics context that is optimized for the screen
    // the source image is 1x so it's forced here. If you have a 2x image
    // set the final arg to zero.
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(512.0, 512.0),
                                           YES, 1.0);
    // find and load the image, we are on a background thread so dataWihtContentsOfURL:
    // is fine
    NSURL *url = [[NSBundle mainBundle] URLForResource:name withExtension:extension];
    UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:url]];
    // draw the image, since the screen context created with UIGraphicsBeginImageContextWithOptions
    // is current this draws as expected into that context
    //
    // before this call we have allocated 512x512x4 (1.05MB) of
    // memory for the context and loaded the compressed image into memory
    // after this call the image is decompressed (also 1.05MB) and then
    // drawn into the context, which is still 1.05MB so we have 2.1MB
    // used for this little dance. After we return and ARC cleans up
    // there is 1.05 for the screen image.
    [image drawInRect:CGRectMake(0.0, 0.0, 512.0, 512.0)];
    // at this point image has a decompressed version of it's self
    // we could return that and we'd have a decompressed jpg or png or whatever
    // however, it would not necessarly be optimized for display on the screen
    // if we get the image from the graphics context we'll have something optimized
    // for the screen
    UIImage *screenOptimizedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    dispatch_async(dispatch_get_main_queue(), ^{
      completionBlock(screenOptimizedImage);
    });
  }];
}

@end
