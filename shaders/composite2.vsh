#version 410 compatibility
#define composite2
#define vsh
#define ShaderStage 10
#include "/lib/Syntax.glsl"


uniform mat4 gbufferModelView;
uniform mat4 shadowModelView;

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
	texcoord    = gl_MultiTexCoord0.st;
	gl_Position = ftransform();
	
	
	#include "/lib/Uniform/Composite_Calculations.vsh"
}
