#version 410 compatibility
#define composite0
#define vsh
#define ShaderStage 10
#include "/lib/Syntax.glsl"


uniform mat4 gbufferModelView;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

uniform vec3 upPosition;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform float sunAngle;
uniform float frameTimeCounter;

varying vec2 texcoord;

#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"
#include "/lib/Uniform/Global_Composite_Variables.glsl"
#include "/lib/Uniform/ShadowViewMatrix.vsh"


void main() {
#if defined GI_ENABLED || defined AO_ENABLED
	texcoord    = gl_MultiTexCoord0.st;
	gl_Position = ftransform();
	
	gl_Position.xy = ((gl_Position.xy * 0.5 + 0.5) * COMPOSITE0_SCALE) * 2.0 - 1.0;
	
	
	#include "/lib/Uniform/Composite_Calculations.vsh"
#else
	gl_Position = vec4(-1.0);
#endif
}
