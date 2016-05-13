#version 120
#define composite_vsh true
#define ShaderStage 10

#define COMPOSITE0_SCALE 0.40

uniform float viewWidth;
uniform float viewHeight;

varying vec2 texcoord;

//#include include/PostHeader.vsh"
uniform vec3 sunPosition;
uniform vec3 upPosition;

varying vec3 lightVector;

varying float timeDay;
varying float timeNight;
varying float timeHorizon;

varying vec3 colorSunlight;
varying vec3 colorSkylight;

float clamp01(in float x) {
	return clamp(x, 0.0, 1.0);
}

#define PI 3.14159
//#include include/PostHeader.vsh"


void main() {
	texcoord    = gl_MultiTexCoord0.st;
	gl_Position = ftransform();
	
	gl_Position.xy = ((gl_Position.xy * 0.5 + 0.5) * COMPOSITE0_SCALE) * 2.0 - 1.0;
	
	
	#include "/lib/CompositeCalculations.vsh"
}