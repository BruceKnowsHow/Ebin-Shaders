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

varying float tbnIndex;

#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"
#include "/lib/DebugSetup.glsl"


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


float EncodePlanarTBN(in vec3 worldNormal) { // Encode the TBN matrix into a 3-bit float
	// Only valid for axis-oriented TBN matrices
	
	float tbnIndex = 5.0; // Default is 5.0, which corresponds to an upward facing block, such as ocean
	
	cfloat sqrt2 = sqrt(2.0) * 0.5;
	
	if      (worldNormal.x >  sqrt2) tbnIndex = 0.0;
	else if (worldNormal.x < -sqrt2) tbnIndex = 1.0;
	else if (worldNormal.z >  sqrt2) tbnIndex = 2.0;
	else if (worldNormal.z < -sqrt2) tbnIndex = 3.0;
	else if (worldNormal.y < -sqrt2) tbnIndex = 4.0;
	
	return tbnIndex;
}

void main() {
	color         = gl_Color.rgb;
	texcoord      = gl_MultiTexCoord0.st;
	lightmapCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).st;
	mcID          = mc_Entity.x;
	
	vertLightmap = GetDefaultLightmap(lightmapCoord);
	materialIDs  = GetMaterialIDs(int(mcID));
	materialIDs1 = vec4(0.0, 0.0, 0.0, 0.0);
	
	tbnIndex = EncodePlanarTBN(gl_Normal);
	
	vec4 position = GetWorldSpacePosition();
	
	position.xyz += CalculateVertexDisplacements(position.xyz);
	
	gl_Position   = WorldSpaceToProjectedSpace(position);
	
	
	CalculateTBN(position.xyz, tbnMatrix, vertNormal);
	
	viewSpacePosition = gbufferModelView * position;
	worldPosition     = position.xyz + cameraPosition;
	
	
	exit();
}