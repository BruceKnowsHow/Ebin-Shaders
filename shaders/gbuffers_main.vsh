attribute vec4 mc_Entity;
attribute vec4 at_tangent;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;

uniform vec3  cameraPosition;
uniform float frameTimeCounter;

varying vec3 color;
varying vec2 texcoord;

varying mat3 tbnMatrix;
varying vec4 verts;
varying vec2 vertLightmap;

varying float mcID;
varying float materialIDs;

varying vec4 viewSpacePosition;
varying vec3 worldPosition;

varying float tbnIndex;
varying float waterMask;

#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"
#include "/lib/Debug.glsl"

#if defined gbuffers_water
#include "/lib/Uniform/Global_Composite_Variables.glsl"
#include "/lib/Uniform/ShadowViewMatrix.vsh"
#endif


vec2 GetDefaultLightmap(vec2 lightmapCoord) { // Gets the lightmap from the default lighting engine, ignoring any texture pack lightmap. First channel is torch lightmap, second channel is sky lightmap.
	return clamp((lightmapCoord * pow2(1.031)) - 0.032, 0.0, 1.0).st; // Default lightmap texture coordinates work somewhat as lightmaps, however they need to be adjusted to use the full range of 0.0-1.0
}

#include "/lib/Vertex/Materials.vsh"

vec4 GetWorldSpacePosition() {
	return gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
}

vec4 WorldSpaceToProjectedSpace(vec4 worldSpacePosition) {
#if !defined gbuffers_hand
	return gbufferProjection * gbufferModelView * worldSpacePosition;
#else
	return gl_ProjectionMatrix * gbufferModelView * worldSpacePosition;
#endif
}

#include "/lib/Vertex/Waving.vsh"
#include "/lib/Vertex/Vertex_Displacements.vsh"
#include "/lib/Vertex/CalculateTBN.vsh"


float EncodePlanarTBN(vec3 worldNormal) { // Encode the TBN matrix into a 3-bit float
	// Only valid for axis-oriented TBN matrices
	
	float tbnIndex = 6.0; // Default is 5.0, which corresponds to an upward facing block, such as ocean
	
	cfloat sqrt2 = sqrt(2.0) * 0.5;
	
	if      (worldNormal.x >  sqrt2) tbnIndex = 1.0;
	else if (worldNormal.x < -sqrt2) tbnIndex = 2.0;
	else if (worldNormal.z >  sqrt2) tbnIndex = 3.0;
	else if (worldNormal.z < -sqrt2) tbnIndex = 4.0;
	else if (worldNormal.y < -sqrt2) tbnIndex = 5.0;
	
	return tbnIndex;
}

void main() {
	color        = gl_Color.rgb;
	texcoord     = gl_MultiTexCoord0.st;
	mcID         = mc_Entity.x;
	waterMask    = float(abs(mc_Entity.x - 8.5) < 0.6);
	vertLightmap = GetDefaultLightmap((gl_TextureMatrix[1] * gl_MultiTexCoord1).st);
	materialIDs  = GetMaterialIDs(int(mc_Entity.x));
	tbnIndex     = EncodePlanarTBN(gl_Normal);
	
	vec4 position = GetWorldSpacePosition();
	
	position.xyz += CalculateVertexDisplacements(position.xyz, vertLightmap.g);
	
	gl_Position   = WorldSpaceToProjectedSpace(position);
	
	
	CalculateTBN(position.xyz, tbnMatrix);
	verts = gl_Vertex;
	
	viewSpacePosition = gbufferModelView * position;
	worldPosition     = position.xyz + cameraPosition;
	
	
#if defined gbuffers_water
	#include "/lib/Uniform/Composite_Calculations.vsh"
#endif
	
	
	exit();
}
