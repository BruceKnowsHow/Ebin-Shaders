#version 120
#define composite3_vsh true
#define ShaderStage 10

//#define COMPOSITE0_VERTEX
#define COMPOSITE3_VERTEX

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
	
	
	vec2 pixelSize = 1.0 / vec2(viewWidth, viewHeight);
	
	vec2 vertexScale = vec2(0.25 + pixelSize.x * 2.0, 0.375 + pixelSize.y * 4.0);
	
	gl_Position.xy = ((gl_Position.xy * 0.5 + 0.5) * vertexScale) * 2.0 - 1.0; // Crop the vertex to only cover the areas that are being used
	
	texcoord *= vertexScale; // Compensate for the vertex adjustment to make this a true "crop" rather than a "downscale"
}