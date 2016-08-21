#version 410 compatibility
#define final
#define vsh
#define ShaderStage 10
#include "/lib/Syntax.glsl"
#line 7

uniform float viewWidth;
uniform float viewHeight;

varying vec2 texcoord;
varying vec2 pixelSize;

void main() {
	texcoord    = gl_MultiTexCoord0.st;
	gl_Position = ftransform();
	
	pixelSize = 1.0 / vec2(viewWidth, viewHeight);
}
