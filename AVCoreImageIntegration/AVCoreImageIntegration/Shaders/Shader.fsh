//
//  Shader.fsh
//  AVCoreImageIntegration
//
//  Created by Bill Dudney on 2/21/13.
//  Copyright (c) 2013 Bill Dudney. All rights reserved.
//

varying lowp vec2 texCoordsVarying;
uniform sampler2D texture;

void main() {
  gl_FragColor = texture2D(texture, texCoordsVarying);
}
