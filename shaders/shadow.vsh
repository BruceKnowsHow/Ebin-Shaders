#version 410 compatibility
#define gbuffers_shadow
#define vsh
#define ShaderStage -2
#include "/lib/Syntax.glsl"


attribute vec4 mc_Entity;
attribute vec4 at_tangent;

uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform float sunAngle;
uniform float frameTimeCounter;

varying vec4 color;
varying vec2 texcoord;
varying vec2 lightmapCoord;

varying vec3 vertNormal;

#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"
#include "/lib/Uniform/ShadowViewMatrix.vsh"

vec4 GetWorldSpacePositionShadow() {
	return shadowModelViewInverse * shadowProjectionInverse * ftransform();
}

vec4 WorldSpaceToShadowProjection(in vec4 worldSpacePosition) {
	return shadowProjection * shadowModelView * worldSpacePosition;
}

vec4 WorldSpaceToShadowProjection1(in vec4 worldSpacePosition) {
	return shadowProjection * shadowView * worldSpacePosition;
}

#include "/lib/Vertex/Waving.vsh"
#include "/lib/Vertex/VertexDisplacements.vsh"
#include "/lib/Vertex/CalculateTBN.vsh"

#include "/lib/Misc/BiasFunctions.glsl"

vec4 BiasShadowProjection(in vec4 position) {
	float biasCoeff = GetShadowBias(position.xy);
	
	position.xy /= biasCoeff;
	
	position.z  += 0.001 * max(0.0, 1.0 - dot(vertNormal, vec3(0.0, 0.0, 1.0))); // Offset the z-coordinate to fix shadow acne
	position.z  += 0.0005 / (abs(position.x) + 1.0);
	position.z  += 0.002 * pow(biasCoeff * 2.0, 2.0);
	
	position.z  /= 4.0; // Shrink the domain of the z-buffer. This counteracts the noticable issue where far terrain would not have shadows cast, especially when the sun was near the horizon
	
	return position;
}


void main() {
	if (abs(mc_Entity.x - 8.5) < 0.6) return; // Discard water
	
	CalculateShadowView();
	
	color         = gl_Color;
	texcoord      = gl_MultiTexCoord0.st;
	lightmapCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).st;
	
	vertNormal    = normalize((shadowView * shadowModelViewInverse * vec4(gl_NormalMatrix * gl_Normal, 0.0)).xyz);
	
	
	vec4 position = GetWorldSpacePositionShadow();
	
	position.xyz += CalculateVertexDisplacements(position.xyz);
	
	gl_Position = BiasShadowProjection(WorldSpaceToShadowProjection1(position));
	
	
	#ifndef PLAYER_SHADOW
	if (   mc_Entity.x == 0 // If the vertex is an entity
		&& abs(position.x) < 1.0
		&& position.y > -0.1 &&  position.y < 2.0 // Check if the vertex is in A bounding box around the player, so that at least non-near entities still cast shadows
		&& abs(position.z) < 1.0
	) color.a = 0.0;
	#endif
}
