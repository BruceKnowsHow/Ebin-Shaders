#version 120
#define composite_vsh true
#define ShaderStage 10

uniform mat4 gbufferModelView;
uniform mat4 shadowModelView;

uniform vec3 upPosition;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform float sunAngle;
uniform float frameTimeCounter;

varying vec2 texcoord;

#include "/lib/Settings.glsl"
#include "/lib/Util.glsl"
#include "/lib/ShadowViewMatrix.vsh"
#include "/lib/GlobalCompositeVariables.glsl"


void main() {
	texcoord    = gl_MultiTexCoord0.st;
	gl_Position = ftransform();
	
	gl_Position.xy = ((gl_Position.xy * 0.5 + 0.5) * COMPOSITE0_SCALE) * 2.0 - 1.0;
	
	
	#include "/lib/CompositeCalculations.vsh"
}