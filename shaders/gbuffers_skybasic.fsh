#version 120
#define skybasic_fsh true
#define ShaderStage -1

/* DRAWBUFFERS:2 */

uniform sampler2D texture;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

uniform vec3 cameraPosition;

uniform float viewWidth;
uniform float viewHeight;

uniform float far;

varying vec3 color;
varying vec2 texcoord;

#include "/lib/Settings.glsl"
#include "/lib/Util.glsl"
#include "/lib/CalculateFogFactor.glsl"
#include "/lib/GlobalCompositeVariables.glsl"


vec4 CalculateViewSpacePosition(in vec2 coord, in float depth) {
	vec4 position  = gbufferProjectionInverse * vec4(vec3(coord, depth) * 2.0 - 1.0, 1.0);
	     position /= position.w;
	
	return position;
}

#include "/lib/Sky.fsh"


void main() {
	vec4 viewSpacePosition = CalculateViewSpacePosition(gl_FragCoord.st / vec2(viewWidth, viewHeight), 1.0);
	
	gl_FragData[0] = vec4(EncodeColor(CalculateSky(viewSpacePosition)), 1.0);
}