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

uniform float far;
uniform float sunAngle;
uniform float frameTimeCounter;

varying mat4 shadowView;
varying mat4 shadowViewInverse;

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


#include "/lib/Vertex/Waving.vsh"
#include "/lib/Vertex/Vertex_Displacements.vsh"
#include "/lib/Vertex/CalculateTBN.vsh"

#include "/lib/Misc/Bias_Functions.glsl"

vec4 ProjectShadowMap(vec4 position) {
	position = shadowProjection * shadowView * position;
	
	float biasCoeff = GetShadowBias(position.xy);
	float scale = GetShadowScale();
	
//	vec4 wlv = inverse(shadowView)[2];
//	position.xyz -= 2.0 * 0.1974 * sin(acos(wlv.xyz)) * sign(wlv.xyz) * biasCoeff * 1024.0 / shadowMapResolution;
	
	position.z  += (0.005 * pow(sin(acos(max0(vertNormal.z))), 4.0) + 0.005 * pow2(biasCoeff)) * scale * 1024.0 / shadowMapResolution;
	
	position.xy /= biasCoeff;
	position.z  /= 6.0; // Shrink the domain of the z-buffer. This counteracts the noticable issue where far terrain would not have shadows cast, especially when the sun was near the horizon
	
	return position;
}


void main() {
	if (abs(mc_Entity.x - 8.5) < 0.6) { gl_Position = vec4(-1.0); return; } // Discard water
	
	CalculateShadowView();
	
	color         = gl_Color;
	texcoord      = gl_MultiTexCoord0.st;
	lightmapCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).st;
	
	vertNormal    = normalize((shadowView * shadowModelViewInverse * vec4(gl_NormalMatrix * gl_Normal, 0.0)).xyz);
	
	
	vec4 position = GetWorldSpacePositionShadow();
	
	position.xyz += CalculateVertexDisplacements(position.xyz, lightmapCoord.g);
	
	gl_Position = ProjectShadowMap(position);
	
	
	#ifndef PLAYER_SHADOW
	if (   mc_Entity.x == 0 // If the vertex is an entity
		&& abs(position.x) < 1.0
		&& position.y > -0.1 &&  position.y < 2.0 // Check if the vertex is A bounding box around the player, so that at least non-near entities still cast shadows
		&& abs(position.z) < 1.0
	) color.a = 0.0;
	#endif
	
	#ifndef PLAYER_GI_BOUNCE
	if (   mc_Entity.x == 0 // If the vertex is an entity
		&& abs(position.x) < 1.0
		&& position.y > -0.1 &&  position.y < 2.0 // Check if the vertex is A bounding box around the player, so that at least non-near entities still cast shadows
		&& abs(position.z) < 1.0
	) color.rgb = vec3(0.0);
	#endif
}
