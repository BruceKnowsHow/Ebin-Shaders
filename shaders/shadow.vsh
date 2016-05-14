#version 120
#define shadow_vsh true
#define ShaderStage -10

attribute vec4 mc_Entity;
attribute vec4 at_tangent;

uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

uniform vec3 cameraPosition;

uniform float sunAngle;
uniform float frameTimeCounter;

varying mat4 shadowView;
varying mat4 shadowViewInverse;

varying vec4 color;
varying vec2 texcoord;
varying vec2 lightmapCoord;

varying vec3 vertNormal;

#include "/lib/Settings.glsl"
#include "/lib/Util.glsl"

vec4 GetWorldSpacePositionShadow() {
	return shadowModelViewInverse * shadowProjectionInverse * ftransform();
}

vec4 WorldSpaceToShadowProjection(in vec4 worldSpacePosition) {
	return shadowProjection * shadowModelView * worldSpacePosition;
}

vec4 WorldSpaceToShadowProjection1(in vec4 worldSpacePosition) {
	return shadowProjection * shadowView * worldSpacePosition;
}

#include "/lib/Waving.vsh"
#include "/lib/VertexDisplacements.vsh"
#include "/lib/CalculateTBN.vsh"
#include "/lib/BiasFunctions.glsl"

vec4 BiasShadowProjection(in vec4 position) {
	float biasCoeff = GetShadowBias(position.xy);
	
	position.xy /= biasCoeff;
	
	position.z  += 0.002 * max(0.0, 1.0 - dot(vertNormal, vec3(0.0, 0.0, 1.0))); // Offset the z-coordinate to fix shadow acne
	position.z  += 0.0005 / (abs(position.x) + 1.0);
	position.z  += 0.002 * pow(biasCoeff * 2.0, 2.0);
	
	position.z  /= 4.0; // Shrink the domain of the z-buffer. This counteracts the noticable issue where far terrain would not have shadows cast, especially when the sun was near the horizon
	
	return position;
}

#include "/lib/ShadowViewMatrix.vsh"


void main() {
	CalculateShadowView();
	
	color         = gl_Color;
	texcoord      = gl_MultiTexCoord0.st;
	lightmapCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).st;
	
	vertNormal    = normalize((shadowView * shadowModelViewInverse * vec4(gl_NormalMatrix * gl_Normal, 0.0)).xyz);
	
	
	vec4 position = GetWorldSpacePositionShadow();
	
	position.xyz += CalculateVertexDisplacements(position.xyz);
	
	gl_Position = BiasShadowProjection(WorldSpaceToShadowProjection1(position));
	
	
	#ifdef FORWARD_SHADING
		if (abs(mc_Entity.x - 8.5) < 0.6) gl_Position.w = -1.0;
	#else
		if (abs(mc_Entity.x - 8.5) < 0.6) color.rgb *= 0.0; // Make water black, so that it doesn't bounce light
	#endif
	
	#ifndef PLAYER_SHADOW
	if (   mc_Entity.x == 0 // If the vertex is an entity
		&& abs(position.x) < 1.0
		&& position.y > -0.1 &&  position.y < 2.0 // Check if the vertex is in A bounding box around the player, so that at least non-near entities still cast shadows
		&& abs(position.z) < 1.0
	) color.a = 0.0;
	#endif
}