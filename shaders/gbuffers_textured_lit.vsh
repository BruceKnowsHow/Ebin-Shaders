#version 120
#define textured_lit_vsh true
#define ShaderStage -10

attribute vec4 mc_Entity;
attribute vec4 at_tangent;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

uniform vec3  cameraPosition;
uniform float rainStrength;
uniform float frameTimeCounter;

varying vec3 color;
varying vec2 texcoord;
varying vec2 lightmapCoord;

varying vec3 vertNormal;
varying mat3 tbnMatrix;
varying vec2 vertLightmap;

varying float materialIDs;
varying float encodedMaterialIDs;

varying vec4 viewSpacePosition;
varying vec3 worldPosition;


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

#include "/lib/Materials.vsh"

vec4 GetWorldSpacePosition() {
	return gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
}

vec4 WorldSpaceToProjectedSpace(in vec4 worldSpacePosition) {
	return gl_ProjectionMatrix * gbufferModelView * worldSpacePosition;
}

#include "/lib/Waving.vsh"
#include "/lib/VertexDisplacements.vsh"
#include "/lib/CalculateTBN.vsh"


void main() {
	color         = gl_Color.rgb;
	texcoord      = gl_MultiTexCoord0.st;
	lightmapCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).st;
	
	vertLightmap       = GetDefaultLightmap(lightmapCoord);
	materialIDs        = GetMaterialIDs(int(mc_Entity.x));
	encodedMaterialIDs = EncodeMaterialIDs(materialIDs, 0.0, 0.0, 0.0, 0.0);
	
	
	vec4 position = GetWorldSpacePosition();
	
	position.xyz += CalculateVertexDisplacements(position.xyz);
	
	gl_Position   = WorldSpaceToProjectedSpace(position);
	
	
	CalculateTBN(position.xyz, tbnMatrix, vertNormal);
	
	worldPosition     = position.xyz + cameraPosition;
	viewSpacePosition = gbufferModelView * position;
	
//#include "include/PostCalculations.vsh"
	vec3 sunVector = normalize(sunPosition); //Engine-time overrides will happen by modifying sunVector
	
	lightVector = sunVector * mix(1.0, -1.0, float(dot(sunVector, upPosition) < 0.0));
	
	
	float sunUp   = dot(sunVector, normalize(upPosition));
	
	timeDay      = sin( sunUp * PI * 0.5);
	timeNight    = sin(-sunUp * PI * 0.5);
	timeHorizon  = pow(1 + timeDay * timeNight, 4.0);
	
	float horizonClip = max(0.0, 0.9 - timeHorizon) / 0.9;
	
	timeDay = clamp01(timeDay * horizonClip);
	timeNight = clamp01(timeNight * horizonClip);
	
	float timeSunrise  = timeHorizon * timeDay;
	float timeMoonrise = timeHorizon * timeNight;
	
	vec3 sunlightDay =
	vec3(1.0, 1.0, 1.0);
	
	vec3 sunlightNight =
	vec3(0.43, 0.65, 1.0) * 0.025;
	
	vec3 sunlightSunrise =
	vec3(1.00, 0.50, 0.00);
	
	vec3 sunlightMoonrise =
	vec3(0.90, 1.00, 1.00);
	
	colorSunlight  = sunlightDay * timeDay + sunlightNight * timeNight + sunlightSunrise * timeSunrise + sunlightMoonrise * timeMoonrise;
	
	
	const vec3 skylightDay =
	vec3(0.24, 0.58, 1.00);
	
	const vec3 skylightNight =
	vec3(0.25, 0.5, 1.0) * 0.025;
	
	const vec3 skylightHorizon =
	vec3(0.29, 0.48, 1.0) * 0.01;
	
	colorSkylight = skylightDay * timeDay + skylightNight * timeNight + skylightHorizon * timeHorizon;
//#include "include/PostCalculations.vsh"
}