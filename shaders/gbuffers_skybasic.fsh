#version 410 compatibility
#define gbuffers_skybasic
#define fsh
#define ShaderStage -1
#include "/lib/Syntax.glsl"


/* DRAWBUFFERS:2 */

uniform sampler2D texture;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

uniform vec3 cameraPosition;

uniform float viewWidth;
uniform float viewHeight;

uniform float far;

uniform int isEyeInWater;

varying vec3 color;
varying vec2 texcoord;

#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"
#include "/lib/DebugSetup.glsl"
#include "/lib/CalculateFogFactor.glsl"
#include "/lib/GlobalCompositeVariables.glsl"


vec4 CalculateViewSpacePosition(in vec2 coord, in float depth) {
	vec4 position  = gbufferProjectionInverse * vec4(vec3(coord, depth) * 2.0 - 1.0, 1.0);
	     position /= position.w;
	
	return position;
}

#include "/lib/Fragment/Sky.fsh"


void main() {
	vec4 viewSpacePosition = CalculateViewSpacePosition(gl_FragCoord.st / vec2(viewWidth, viewHeight), 1.0);
	
#ifdef FORWARD_SHADING
	gl_FragData[0] = vec4(EncodeColor(CalculateSky(viewSpacePosition, true)), 1.0);
#else
	gl_FragData[0] = vec4(CalculateSky(viewSpacePosition, true) * 0.05, 1.0);
#endif
	
	exit();
}