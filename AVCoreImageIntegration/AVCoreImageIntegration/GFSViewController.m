//
//  GFSViewController.m
//  AVCoreImageIntegration
//
//  Created by Bill Dudney on 2/21/13.
//  Copyright (c) 2013 Bill Dudney. All rights reserved.
//

#import "GFSViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreImage/CoreImage.h>
#import <GLKit/GLKit.h>


#define BUFFER_OFFSET(i) ((char *)NULL + (i))

// Uniform index.
enum {
  UNIFORM_MODELVIEWPROJECTION_MATRIX,
  UNIFORM_TEXTURE,
  NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

// Attribute index.
enum {
  ATTRIB_VERTEX,
  ATTRIB_TEXCOORDS,
  NUM_ATTRIBUTES
};

GLfloat gCubeVertexData[6 * 6 * 8] = {
  // the Normals are not used in the shader for this app
  // however they could be used to tweak the final pixel values
  // if you wanted to set up some sort of lighting
  
  // Data layout for each line below is:
  //  Position                    Normal                      Texture
  //  x, y, z,                    x, y, z,                    s,    t
  //  Plus X
      0.5f, -0.5f, -0.5f,         1.0f, 0.0f, 0.0f,           1.0f, 1.0f,
      0.5f,  0.5f, -0.5f,         1.0f, 0.0f, 0.0f,           1.0f, 0.0f,
      0.5f, -0.5f,  0.5f,         1.0f, 0.0f, 0.0f,           0.0f, 1.0f,
      0.5f, -0.5f,  0.5f,         1.0f, 0.0f, 0.0f,           0.0f, 1.0f,
      0.5f,  0.5f, -0.5f,         1.0f, 0.0f, 0.0f,           1.0f, 0.0f,
      0.5f,  0.5f,  0.5f,         1.0f, 0.0f, 0.0f,           0.0f, 0.0f,
   // Plus Y
      0.5f, 0.5f, -0.5f,         0.0f, 1.0f, 0.0f,            1.0f, 0.0f,
     -0.5f, 0.5f, -0.5f,         0.0f, 1.0f, 0.0f,            0.0f, 0.0f,
      0.5f, 0.5f,  0.5f,         0.0f, 1.0f, 0.0f,            1.0f, 1.0f,
      0.5f, 0.5f,  0.5f,         0.0f, 1.0f, 0.0f,            1.0f, 1.0f,
     -0.5f, 0.5f, -0.5f,         0.0f, 1.0f, 0.0f,            0.0f, 0.0f,
     -0.5f, 0.5f,  0.5f,         0.0f, 1.0f, 0.0f,            0.0f, 1.0f,
   // Minus X
     -0.5f,  0.5f, -0.5f,       -1.0f, 0.0f, 0.0f,            0.0f, 1.0f,
     -0.5f, -0.5f, -0.5f,       -1.0f, 0.0f, 0.0f,            1.0f, 1.0f,
     -0.5f,  0.5f,  0.5f,       -1.0f, 0.0f, 0.0f,            0.0f, 0.0f,
     -0.5f,  0.5f,  0.5f,       -1.0f, 0.0f, 0.0f,            0.0f, 0.0f,
     -0.5f, -0.5f, -0.5f,       -1.0f, 0.0f, 0.0f,            1.0f, 1.0f,
     -0.5f, -0.5f,  0.5f,       -1.0f, 0.0f, 0.0f,            1.0f, 0.0f,
   // Minus Y
     -0.5f, -0.5f, -0.5f,        0.0f, -1.0f, 0.0f,           1.0f, 0.0f,
      0.5f, -0.5f, -0.5f,        0.0f, -1.0f, 0.0f,           0.0f, 0.0f,
     -0.5f, -0.5f,  0.5f,        0.0f, -1.0f, 0.0f,           1.0f, 1.0f,
     -0.5f, -0.5f,  0.5f,        0.0f, -1.0f, 0.0f,           1.0f, 1.0f,
      0.5f, -0.5f, -0.5f,        0.0f, -1.0f, 0.0f,           0.0f, 0.0f,
      0.5f, -0.5f,  0.5f,        0.0f, -1.0f, 0.0f,           0.0f, 1.0f,
   // Plus Z
      0.5f,  0.5f, 0.5f,         0.0f, 0.0f, 1.0f,           0.0f, 0.0f,
     -0.5f,  0.5f, 0.5f,         0.0f, 0.0f, 1.0f,           0.0f, 1.0f,
      0.5f, -0.5f, 0.5f,         0.0f, 0.0f, 1.0f,           1.0f, 0.0f,
      0.5f, -0.5f, 0.5f,         0.0f, 0.0f, 1.0f,           1.0f, 0.0f,
     -0.5f,  0.5f, 0.5f,         0.0f, 0.0f, 1.0f,           0.0f, 1.0f,
     -0.5f, -0.5f, 0.5f,         0.0f, 0.0f, 1.0f,           1.0f, 1.0f,
   // Minus Z
      0.5f, -0.5f, -0.5f,        0.0f, 0.0f, -1.0f,           0.0f, 1.0f,
     -0.5f, -0.5f, -0.5f,        0.0f, 0.0f, -1.0f,           1.0f, 1.0f,
      0.5f,  0.5f, -0.5f,        0.0f, 0.0f, -1.0f,           0.0f, 0.0f,
      0.5f,  0.5f, -0.5f,        0.0f, 0.0f, -1.0f,           0.0f, 0.0f,
     -0.5f, -0.5f, -0.5f,        0.0f, 0.0f, -1.0f,           1.0f, 1.0f,
     -0.5f,  0.5f, -0.5f,        0.0f, 0.0f, -1.0f,           1.0f, 0.0f
};

@interface GFSViewController () <AVCaptureVideoDataOutputSampleBufferDelegate> {
  AVCaptureSession *_session;
  NSArray *_filters;
  CIContext *_ciContext;
  
  GLuint _program;
  
  GLKMatrix4 _modelViewProjectionMatrix;
  GLKMatrix3 _normalMatrix;
  GLKMatrix4 _modelViewProjectionMatrix2;
  float _rotation;
  
  GLuint _vertexArray;
  GLuint _vertexBuffer;
  
  GLuint _textureFramebuffer;
  GLuint _sourceTexture;
  
  CVOpenGLESTextureCacheRef _textureCache;
  CVOpenGLESTextureRef _cameraTexture;
  size_t _textureWidth;
  size_t _textureHeight;
  GLKTextureInfo *_electricTexture;
  GLKTextureInfo *_epcotTexture;
  
  BOOL _animate;
}

@property (strong, nonatomic) EAGLContext *context;

- (void)setupGL;
- (void)tearDownGL;

- (BOOL)loadShaders;
- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file;
- (BOOL)linkProgram:(GLuint)prog;
- (BOOL)validateProgram:(GLuint)prog;

@end

@implementation GFSViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  
  self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
  self.preferredFramesPerSecond = 60.0;
  
  if (!self.context) {
    NSLog(@"Failed to create ES context");
  }
  
  GLKView *view = (GLKView *)self.view;
  view.context = self.context;
  view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
  
  [self setupGL];
  [self setupCoreImage];
  [self setupCamera];
  [self setupTextures];
  [self setupCoreImageFramebuffer];
  
  _animate = YES;
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  [self startCapture:nil];
}

- (void)dealloc {
  // cleanup when being dealloced
  [self tearDownGL];
  
  if ([EAGLContext currentContext] == self.context) {
    [EAGLContext setCurrentContext:nil];
  }
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  
  if ([self isViewLoaded] && ([[self view] window] == nil)) {
    self.view = nil;
    
    [self tearDownGL];
    
    if ([EAGLContext currentContext] == self.context) {
      [EAGLContext setCurrentContext:nil];
    }
    self.context = nil;
  }
}

#pragma mark - Actions

- (IBAction)startCapture:(id)sender {
  if(!_session.running) {
    [_session startRunning];
  }
  _animate = YES;
}

- (IBAction)stopCapture:(id)sender {
  if(_session.running) {
    [_session stopRunning];
  }
  _animate = NO;
}

#pragma mark - Setup Resources

- (void)setupTextures {
  NSError *error = nil;
  NSURL *imageURL = [[NSBundle mainBundle] URLForResource:@"electrical" withExtension:@"jpg"];
  _electricTexture = [GLKTextureLoader textureWithContentsOfURL:imageURL
                                                options:nil
                                                  error:&error];
  if(!_electricTexture) {
    NSLog(@"error loading electric texture %@ info %@", error, error.userInfo);
  }
  error = nil;
  imageURL = [[NSBundle mainBundle] URLForResource:@"epcot" withExtension:@"jpg"];
  _epcotTexture = [GLKTextureLoader textureWithContentsOfURL:imageURL
                                                     options:nil
                                                       error:&error];
  if(!_epcotTexture) {
    NSLog(@"error loading texture %@ info %@", error, error.userInfo);
  }
}

- (void)cleanupTextures {
  if(_cameraTexture) {
    CFRelease(_cameraTexture);
    _cameraTexture = NULL;
  }
  CVOpenGLESTextureCacheFlush(_textureCache, 0);
}

#pragma mark - Setup CI Filters

- (void)setupCoreImage {
  NSMutableArray *filters = [NSMutableArray array];
  CIFilter *filter = [CIFilter filterWithName:@"CIDotScreen"];
  [filter setDefaults];
  [filters addObject:filter];
  _filters = [filters copy];

  _ciContext = [CIContext contextWithEAGLContext:self.context];
}

#pragma mark - Setup AVFoundation and Camera support

- (void)setupCamera {
  _session = [[AVCaptureSession alloc] init];
  [_session beginConfiguration];
  [_session setSessionPreset:AVCaptureSessionPresetHigh];
  NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
  AVCaptureDevice *frontCamera = nil;
  for(AVCaptureDevice *device in devices) {
    if(device.position == AVCaptureDevicePositionFront) {
      frontCamera = device;
      break;
    }
  }
  CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, [self context], NULL, &_textureCache);
  if(kCVReturnSuccess != err) {
    NSLog(@"hosed texture cache create %d", err);
  }
  NSError *error = nil;
  AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:frontCamera
                                                                      error:&error];
  if(!input) {
    NSLog(@"error getting front camera %@ info %@", error, error.userInfo);
  } else {
    [_session addInput:input];
    AVCaptureVideoDataOutput *dataOutput = [[AVCaptureVideoDataOutput alloc] init];
    [dataOutput setAlwaysDiscardsLateVideoFrames:YES];
    NSDictionary *options = @{(id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)};
    [dataOutput setVideoSettings:options];
    [dataOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    [_session addOutput:dataOutput];
  }
  [_session commitConfiguration];
}

#pragma mark - AV Data Capture Delegate

static NSInteger droppedFrameCount = 0;
- (void)captureOutput:(AVCaptureOutput *)captureOutput
  didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
  NSLog(@"dropped a frame");
  droppedFrameCount++;
  if(droppedFrameCount > 10) {
    [_session stopRunning];
  }
}

- (void)   captureOutput:(AVCaptureOutput *)captureOutput
   didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
          fromConnection:(AVCaptureConnection *)connection {
  CVPixelBufferRef pixelBuf = (CVPixelBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
  if(pixelBuf) {
    [self cleanupTextures];
    _textureWidth = CVPixelBufferGetWidth(pixelBuf);
    _textureHeight = CVPixelBufferGetHeight(pixelBuf);
    CVReturn err = 0;
    err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                       _textureCache,
                                                       pixelBuf,
                                                       NULL,
                                                       GL_TEXTURE_2D,
                                                       GL_RGBA,
                                                       _textureWidth,
                                                       _textureHeight,
                                                       GL_BGRA,
                                                       GL_UNSIGNED_BYTE,
                                                       0,
                                                       &_cameraTexture);
    if(kCVReturnSuccess == err) {
      CIImage *image = [CIImage imageWithCVPixelBuffer:pixelBuf];
      for(CIFilter *filter in _filters) {
        [filter setValue:image forKey:kCIInputImageKey];
        image = filter.outputImage;
      }
      GLint oldFramebuffer = 0;
      glGetIntegerv(GL_FRAMEBUFFER_BINDING, &oldFramebuffer);
      glBindFramebuffer(GL_FRAMEBUFFER, _textureFramebuffer);
      [_ciContext drawImage:image
                     inRect:CGRectMake(0.0, 0.0, 512.0, 512.0)
                   fromRect:image.extent];
      // release the input image so we are not keeping more buffers than we need
      for(CIFilter *filter in _filters) {
        [filter setValue:nil forKey:kCIInputImageKey];
      }
      glBindFramebuffer(GL_FRAMEBUFFER, oldFramebuffer);
      GLenum error = glGetError();
      if(error != GL_NO_ERROR) {
        NSLog(@"error = %d", error);
      }
    } else {
      NSLog(@"Couldn't create a texture from pixel buffer. Error code => %d", err);
    }
  }
}

#pragma mark - Setup OpenGL

- (void)setupGL {
  [EAGLContext setCurrentContext:self.context];
  
  [self loadShaders];
  
  glEnable(GL_DEPTH_TEST);
  
  glGenVertexArraysOES(1, &_vertexArray);
  glBindVertexArrayOES(_vertexArray);
  
  glGenBuffers(1, &_vertexBuffer);
  glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
  glBufferData(GL_ARRAY_BUFFER, sizeof(gCubeVertexData), gCubeVertexData, GL_STATIC_DRAW);

  glEnableVertexAttribArray(GLKVertexAttribPosition);
  glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(GLfloat), BUFFER_OFFSET(0));
  glEnableVertexAttribArray(GLKVertexAttribNormal);
  glVertexAttribPointer(GLKVertexAttribNormal, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(GLfloat), BUFFER_OFFSET(3 * sizeof(GLfloat)));
  glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
  glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_TRUE, 8 * sizeof(GLfloat), BUFFER_OFFSET(6 * sizeof(GLfloat)));
  
  glBindVertexArrayOES(0);
}

- (void)setupCoreImageFramebuffer {
  GLenum error = GL_NO_ERROR;
  GLint oldFramebuffer = 0;
  glGetIntegerv(GL_FRAMEBUFFER_BINDING, &oldFramebuffer);
  error = glGetError();
  if(error != GL_NO_ERROR) {
    NSLog(@"error = %d", error);
  }
  glGenBuffers(1, &_textureFramebuffer);
  glBindFramebuffer(GL_FRAMEBUFFER, _textureFramebuffer);
  glViewport(0, 0, 512, 512);
  error = glGetError();
  if(error != GL_NO_ERROR) {
    NSLog(@"error = %d", error);
  }
  // create and attach the texture
  glGenTextures(1, &_sourceTexture);
  glBindTexture(GL_TEXTURE_2D, _sourceTexture);
  glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 512, 512, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
  error = glGetError();
  if(error != GL_NO_ERROR) {
    NSLog(@"error = %d", error);
  }
  glFramebufferTexture2D(GL_FRAMEBUFFER,
                         GL_COLOR_ATTACHMENT0,
                         GL_TEXTURE_2D,
                         _sourceTexture,
                         0);
  // check framebuffer status
	GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
	if (status != GL_FRAMEBUFFER_COMPLETE) {
		printf("ERROR: Could not create framebuffer.\n");
		printf("ERROR CODE: 0x%2x\n", status);
	}
  // now that the framebuffer is complet clear it to pink
  glClearColor(1.0, 0.0, 1.0, 1.0);
  glClear(GL_COLOR_BUFFER_BIT);
  // unbind the _sourceTexture
  glBindTexture(GL_TEXTURE_2D, 0);
  // now that we are setup and the new framebuffer is configured we can switch back
  glBindFramebuffer(GL_FRAMEBUFFER, oldFramebuffer);
  error = glGetError();
  if(error != GL_NO_ERROR) {
    NSLog(@"error = %d", error);
  }
  // bind _sourceTexgture to texture 1
  glActiveTexture(GL_TEXTURE1);
  glBindTexture(GL_TEXTURE_2D, _sourceTexture);
}

- (void)tearDownGL {
  [EAGLContext setCurrentContext:self.context];
  
  glDeleteBuffers(1, &_vertexBuffer);
  glDeleteVertexArraysOES(1, &_vertexArray);
  
  if (_program) {
    glDeleteProgram(_program);
    _program = 0;
  }
}

#pragma mark - GLKViewController method overrides

- (void)update {
  if(_animate) {
    CGRect bounds = self.view.bounds;
    
    GLfloat aspect = fabsf(CGRectGetWidth(bounds) / CGRectGetHeight(bounds));
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 0.1f, 100.0f);
    
    GLKMatrix4 baseModelViewMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, -4.0f);
    baseModelViewMatrix = GLKMatrix4Rotate(baseModelViewMatrix, _rotation, 0.0f, 1.0f, 0.0f);
    
    // Compute the model view matrix for the object rendered with GLKit
    GLKMatrix4 modelViewMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, -1.5f);
    modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, _rotation, 1.0f, 1.0f, 1.0f);
    modelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, modelViewMatrix);
    
    // Compute the model view matrix for the object rendered with ES2
    modelViewMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, 1.5f);
    modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, _rotation, 1.0f, 1.0f, 1.0f);
    modelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, modelViewMatrix);
    
    _normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
    
    _modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);

    // the 2nd cube's transformation matrix
    modelViewMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, -1.5f);
    modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, _rotation, 1.0f, 1.0f, 1.0f);
    modelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, modelViewMatrix);
    
    _modelViewProjectionMatrix2 = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
    
    _rotation += self.timeSinceLastUpdate * 0.5f;
  }
}

#pragma mark - GLKView delegate methods

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
  glClearColor(0.65f, 0.65f, 0.65f, 1.0f);
  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
  
  glBindVertexArrayOES(_vertexArray);

  glActiveTexture(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_2D, _electricTexture.name);

  glUseProgram(_program);
  
  // draw cube 1
  glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, _modelViewProjectionMatrix.m);
  glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
  glDrawArrays(GL_TRIANGLES, 0, 36);

  // draw cube 2
  glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, _modelViewProjectionMatrix2.m);
  glUniform1i(uniforms[UNIFORM_TEXTURE], 1);
  glDrawArrays(GL_TRIANGLES, 0, 36);
}

#pragma mark -  OpenGL ES 2 shader compilation

- (BOOL)loadShaders {
  GLuint vertShader, fragShader;
  NSString *vertShaderPathname, *fragShaderPathname;
  
  // Create shader program.
  _program = glCreateProgram();
  
  // Create and compile vertex shader.
  vertShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vsh"];
  if (![self compileShader:&vertShader type:GL_VERTEX_SHADER file:vertShaderPathname]) {
    NSLog(@"Failed to compile vertex shader");
    return NO;
  }
  
  // Create and compile fragment shader.
  fragShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"fsh"];
  if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER file:fragShaderPathname]) {
    NSLog(@"Failed to compile fragment shader");
    return NO;
  }
  
  // Attach vertex shader to program.
  glAttachShader(_program, vertShader);
  
  // Attach fragment shader to program.
  glAttachShader(_program, fragShader);
  
  // Bind attribute locations.
  // This needs to be done prior to linking.
  glBindAttribLocation(_program, GLKVertexAttribPosition, "position");
  glBindAttribLocation(_program, GLKVertexAttribTexCoord0, "texCoords");
  
  // Link program.
  if (![self linkProgram:_program]) {
    NSLog(@"Failed to link program: %d", _program);
    
    if (vertShader) {
      glDeleteShader(vertShader);
      vertShader = 0;
    }
    if (fragShader) {
      glDeleteShader(fragShader);
      fragShader = 0;
    }
    if (_program) {
      glDeleteProgram(_program);
      _program = 0;
    }
    
    return NO;
  }
  
  // Get uniform locations.
  uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX] = glGetUniformLocation(_program, "modelViewProjectionMatrix");
  
  // Release vertex and fragment shaders.
  if (vertShader) {
    glDetachShader(_program, vertShader);
    glDeleteShader(vertShader);
  }
  if (fragShader) {
    glDetachShader(_program, fragShader);
    glDeleteShader(fragShader);
  }
  
  return YES;
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file {
  GLint status;
  const GLchar *source;
  
  source = (GLchar *)[[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil] UTF8String];
  if (!source) {
    NSLog(@"Failed to load vertex shader");
    return NO;
  }
  
  *shader = glCreateShader(type);
  glShaderSource(*shader, 1, &source, NULL);
  glCompileShader(*shader);
  
#if defined(DEBUG)
  GLint logLength;
  glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
  if (logLength > 0) {
    GLchar *log = (GLchar *)malloc(logLength);
    glGetShaderInfoLog(*shader, logLength, &logLength, log);
    NSLog(@"Shader compile log:\n%s", log);
    free(log);
  }
#endif
  
  glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
  if (status == 0) {
    glDeleteShader(*shader);
    return NO;
  }
  
  return YES;
}

- (BOOL)linkProgram:(GLuint)prog {
  GLint status;
  glLinkProgram(prog);
  
#if defined(DEBUG)
  GLint logLength;
  glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
  if (logLength > 0) {
    GLchar *log = (GLchar *)malloc(logLength);
    glGetProgramInfoLog(prog, logLength, &logLength, log);
    NSLog(@"Program link log:\n%s", log);
    free(log);
  }
#endif
  
  glGetProgramiv(prog, GL_LINK_STATUS, &status);
  if (status == 0) {
    return NO;
  }
  
  return YES;
}

- (BOOL)validateProgram:(GLuint)prog {
  GLint logLength, status;
  
  glValidateProgram(prog);
  glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
  if (logLength > 0) {
    GLchar *log = (GLchar *)malloc(logLength);
    glGetProgramInfoLog(prog, logLength, &logLength, log);
    NSLog(@"Program validate log:\n%s", log);
    free(log);
  }
  
  glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
  if (status == 0) {
    return NO;
  }
  
  return YES;
}

@end
