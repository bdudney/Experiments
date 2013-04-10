//
//  Shader.vsh
//  AVCoreImageIntegration
//
//  Created by Bill Dudney on 2/21/13.
//  Copyright (c) 2013 Bill Dudney. All rights reserved.
//

attribute vec4 position;
attribute lowp vec2 texCoords;

varying vec2 texCoordsVarying;
//varying lowp vec4 colorVarying;

uniform mat4 modelViewProjectionMatrix;
//uniform mat3 normalMatrix;

void main()
{
//  vec3 eyeNormal = normalize(normalMatrix * normal);
//  vec3 lightPosition = vec3(0.0, 0.0, 1.0);
//  vec4 diffuseColor = vec4(0.4, 0.4, 1.0, 1.0);
//    
//  float nDotVP = max(0.0, dot(eyeNormal, normalize(lightPosition)));
//  colorVarying = diffuseColor * nDotVP;

  texCoordsVarying = texCoords;
  gl_Position = modelViewProjectionMatrix * position;
}
