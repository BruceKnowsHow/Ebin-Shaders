#version 120
#define hand_vsh true
#define ShaderStage -10

attribute vec4 at_tangent;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

varying vec3 color;
varying vec2 texcoord;
varying vec2 lightmapCoord;

varying vec3 vertNormal;
varying mat3 tbnMatrix;
varying vec2 vertLightmap;

varying float mcID;
varying float materialIDs;
varying vec4  materialIDs1;

varying vec4 viewSpacePosition;


//#include include/PostHeader.vsh"
uniform vec3 sunPosition;
uniform vec3 upPosition;

varying vec3 lightVector;

varying float timeDay;
varying float timeNight;
varying float timeHorizon;

varying vec3 colorSunlight;
varying vec3 colorSkylight;

#include "/lib/Settings.glsl"
#include "/lib/Util.glsl"


vec2 GetDefaultLightmap(in vec2 lightmapCoord) { // Gets the lightmap from the default lighting engine, ignoring any texture pack lightmap. First channel is torch lightmap, second channel is sky lightmap.
	return clamp((lightmapCoord * 1.032) - 0.032, 0.0, 1.0).st; // Default lightmap texture coordinates work somewhat as lightmaps, however they need to be adjusted to use the full range of 0.0-1.0
}

#include "/lib/Materials.glsl"

vec4 GetWorldSpacePosition() {
	return gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
}

vec4 WorldSpaceToProjectedSpace(in vec4 worldSpacePosition) {
	return gl_ProjectionMatrix * gbufferModelView * worldSpacePosition;
}

#include "/lib/CalculateTBN.vsh"


void main() {
	color         = gl_Color.rgb;
	texcoord      = gl_MultiTexCoord0.st;
	lightmapCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).st;
	
	vertLightmap       = GetDefaultLightmap(lightmapCoord);
	materialIDs        = 5.0;
	materialIDs1       = vec4(0.0, 0.0, 0.0, 0.0);
	
	
	vec4 position = GetWorldSpacePosition();
	
	gl_Position = WorldSpaceToProjectedSpace(position);
	
	
	CalculateTBN(position.xyz, tbnMatrix, vertNormal);
	
	viewSpacePosition = gbufferModelView * position;
	
	
#ifdef FORWARD_SHADING
	#include "/lib/CompositeCalculations.vsh"
#endif
}