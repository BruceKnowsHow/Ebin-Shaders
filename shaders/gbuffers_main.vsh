attribute vec4 mc_Entity;
attribute vec4 at_tangent;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 shadowModelView;

uniform vec3 sunPosition;
uniform vec3 upPosition;

uniform vec3  cameraPosition;
uniform float frameTimeCounter;
uniform float sunAngle;

uniform int isEyeInWater;

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
varying vec3 worldPosition;

#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"
#include "/lib/DebugSetup.glsl"
#ifdef FORWARD_SHADING
#include "/lib/Uniform/ShadowViewMatrix.vsh"
#include "/lib/Uniform/GlobalCompositeVariables.glsl"
#endif


vec2 GetDefaultLightmap(in vec2 lightmapCoord) { // Gets the lightmap from the default lighting engine, ignoring any texture pack lightmap. First channel is torch lightmap, second channel is sky lightmap.
	return clamp((lightmapCoord * pow2(1.031)) - 0.032, 0.0, 1.0).st; // Default lightmap texture coordinates work somewhat as lightmaps, however they need to be adjusted to use the full range of 0.0-1.0
}

#include "/lib/Vertex/Materials.vsh"

vec4 GetWorldSpacePosition() {
	return gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
}

vec4 WorldSpaceToProjectedSpace(in vec4 worldSpacePosition) {
#if !defined gbuffers_hand
	return (isEyeInWater == 1 ? gbufferProjection : gl_ProjectionMatrix) * gbufferModelView * worldSpacePosition;
#else
	return gl_ProjectionMatrix * gbufferModelView * worldSpacePosition;
#endif
}

#include "/lib/Vertex/Waving.vsh"
#include "/lib/Vertex/VertexDisplacements.vsh"
#include "/lib/Vertex/CalculateTBN.vsh"

float GetTransparentMask(in float materialIDs) {
#if defined gbuffers_water
	return float(abs(materialIDs - 4.0) > 0.5);
#endif
	
	return 0.0;
}


void main() {
	color         = gl_Color.rgb;
	texcoord      = gl_MultiTexCoord0.st;
	lightmapCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).st;
	mcID          = mc_Entity.x;
	
	vertLightmap = GetDefaultLightmap(lightmapCoord);
	materialIDs  = GetMaterialIDs(int(mcID));
	materialIDs1 = vec4(GetTransparentMask(materialIDs), 0.0, 0.0, 0.0);
	
	
	vec4 position = GetWorldSpacePosition();
	
	position.xyz += CalculateVertexDisplacements(position.xyz);
	
	gl_Position   = WorldSpaceToProjectedSpace(position);
	
	
	CalculateTBN(position.xyz, tbnMatrix, vertNormal);
	
	viewSpacePosition = gbufferModelView * position;
	worldPosition     = position.xyz + cameraPosition;
	
	
#ifdef FORWARD_SHADING
	#include "/lib/Uniform/CompositeCalculations.vsh"
#endif
	
	exit();
}