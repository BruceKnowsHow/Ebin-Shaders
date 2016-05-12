#version 120
#define hand_fsh true
#define ShaderStage -1

/* DRAWBUFFERS:2306 */

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D noisetex;

uniform sampler2DShadow shadow;
uniform sampler2D shadowtex1;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

uniform float frameTimeCounter;
uniform float far;

uniform float viewWidth;
uniform float viewHeight;

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

#include "/lib/MenuInitializer.glsl"
#include "/lib/Settings.glsl"
#include "/lib/Util.glsl"
#include "/lib/DebugSetup.glsl"
#include "/lib/GlobalCompositeVariables.fsh"
#include "/lib/CalculateFogFactor.glsl"
#ifdef FORWARD_SHADING
#include "/lib/Masks.glsl"
#include "/lib/ShadingFunctions.fsh"
#endif


vec4 GetDiffuse() {
	vec4 diffuse = vec4(color.rgb, 1.0);
	     diffuse *= texture2D(texture, texcoord);
	
	return diffuse;
}

vec3 GetNormal() {
	return normalize((texture2D(normals, texcoord).xyz * 2.0 - 1.0) * tbnMatrix);
}

vec2 GetSpecularity() {
	return texture2D(specular, texcoord).rg;
}

#include "/lib/Materials.glsl"


void main() {
	if (CalculateFogFactor(viewSpacePosition, FOG_POWER) >= 1.0) discard;
	
	vec4  diffuse            = GetDiffuse();  if (diffuse.a < 0.1000003) discard; // Non-transparent surfaces will be invisible if their alpha is less than ~0.1000004. This basically throws out invisible leaf and tall grass fragments.
	vec3  normal             = GetNormal();
	vec2  specularity        = GetSpecularity();
	float encodedMaterialIDs = EncodeMaterialIDs(materialIDs, specularity.g, materialIDs1.g, materialIDs1.b, materialIDs1.a);
	
	
	#ifdef DEFERRED_SHADING
		gl_FragData[0] = vec4(diffuse.rgb, diffuse.a);
		gl_FragData[1] = vec4(vertLightmap.st, encodedMaterialIDs, 1.0);
		gl_FragData[2] = vec4(EncodeNormal(normal), specularity.r, 1.0);
	#else
		Mask mask;
		CalculateMasks(mask, encodedMaterialIDs);
		
		vec3 composite = CalculateShadedFragment(diffuse.rgb, mask, vertLightmap.r, vertLightmap.g, normal, specularity.r, viewSpacePosition);
		
		gl_FragData[0] = vec4(EncodeColor(composite), diffuse.a);
		gl_FragData[1] = vec4(vertLightmap.st, encodedMaterialIDs, 1.0);
		gl_FragData[2] = vec4(EncodeNormal(normal), specularity.r, 1.0);
		gl_FragData[3] = vec4(diffuse.rgb, 1.0);
	#endif
	
	exit();
}