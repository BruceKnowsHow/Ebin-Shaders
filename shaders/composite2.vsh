#version 120
#define composite2_vsh true
#define ShaderStage 10

uniform mat4 gbufferModelView;
uniform mat4 shadowModelView;

uniform vec3 sunPosition;
uniform vec3 upPosition;

uniform float sunAngle;

varying mat4 shadowView;
varying mat4 shadowViewInverse;

varying vec2 texcoord;

#include "/lib/Settings.glsl"
#include "/lib/Util.glsl"
#include "/lib/ShadowViewMatrix.vsh"
#include "/lib/GlobalCompositeVariables.glsl"


void main() {
	texcoord    = gl_MultiTexCoord0.st;
	gl_Position = ftransform();
	
	
	CalculateShadowView();
	
	#include "/lib/CompositeCalculations.vsh"
}