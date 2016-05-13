#version 120
#define composite1_vsh true
#define ShaderStage 10

uniform vec3 sunPosition;
uniform vec3 upPosition;

varying vec2 texcoord;

#include "/lib/Settings.glsl"
#include "/lib/Util.glsl"
#include "/lib/GlobalCompositeVariables.glsl"


void main() {
	texcoord    = gl_MultiTexCoord0.st;
	gl_Position = ftransform();
	
	
	#include "/lib/CompositeCalculations.vsh"
}