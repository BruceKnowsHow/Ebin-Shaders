#version 120
#define composite3_vsh true
#define ShaderStage 10

uniform vec3 sunPosition;
uniform vec3 upPosition;

uniform float viewWidth;
uniform float viewHeight;

varying vec2 texcoord;

#include "/lib/Settings.glsl"
#include "/lib/Util.glsl"
#include "/lib/GlobalCompositeVariables.glsl"


void main() {
#ifdef BLOOM_ENABLED
	texcoord    = gl_MultiTexCoord0.st;
	gl_Position = ftransform();
	
	
	vec2 pixelSize = 1.0 / vec2(viewWidth, viewHeight);
	
	vec2 vertexScale = vec2(0.25 + pixelSize.x * 2.0, 0.375 + pixelSize.y * 4.0);
	
	gl_Position.xy = ((gl_Position.xy * 0.5 + 0.5) * vertexScale) * 2.0 - 1.0; // Crop the vertex to only cover the areas that are being used
	
	texcoord *= vertexScale; // Compensate for the vertex adjustment to make this a true "crop" rather than a "downscale"
#else
	gl_Position = vec4(-1.0);
#endif
}