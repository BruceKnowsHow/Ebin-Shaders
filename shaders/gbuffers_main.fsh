/* DRAWBUFFERS:2013 */

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D noisetex;
uniform sampler2D shadowtex1;
uniform sampler2DShadow shadow;

uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;

uniform float frameTimeCounter;
uniform float far;
uniform float wetness;

uniform float viewWidth;
uniform float viewHeight;

varying mat4 shadowView;
#define shadowModelView shadowView

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

#include "/lib/Misc/MenuInitializer.glsl"
#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"
#include "/lib/DebugSetup.glsl"
#include "/lib/Misc/CalculateFogFactor.glsl"
#include "/lib/Fragment/Masks.fsh"


vec4 GetDiffuse() {
	vec4 diffuse  = vec4(color.rgb, 1.0);
	     diffuse *= texture2D(texture, texcoord);
	
	return diffuse;
}

vec4 GetNormal() {
#ifdef NORMAL_MAPS
	vec4 normal = texture2D(normals, texcoord);
#else
	vec4 normal = vec4(0.5, 0.5, 1.0, 1.0);
#endif
	
	normal.xyz = normalize((normal.xyz * 2.0 - 1.0) * tbnMatrix);
	
	return normal;
}

void DoWaterFragment() {
	gl_FragData[0] = vec4(EncodeNormal(transpose(tbnMatrix)[2]), 0.0, 1.0);
	gl_FragData[1] = vec4(0.0);
	gl_FragData[2] = vec4(0.0);
	gl_FragData[3] = vec4(0.0);
}

vec2 GetSpecularity(in float height, in float skyLightmap) {
#ifdef SPECULARITY_MAPS
	vec2 specular = texture2D(specular, texcoord).rg;
	
	float smoothness = specular.r;
	float metalness = specular.g;
	
	float wetfactor = wetness * pow(skyLightmap, 10.0);
	
	smoothness *= 1.0 + wetfactor;
	smoothness += (wetfactor - 0.5) * wetfactor;
	smoothness += (1 - height) * 0.5 * wetfactor;
	
	smoothness = clamp01(smoothness);
	
	return vec2(smoothness, metalness);
#else
	return vec2(0.0);
#endif
}


void main() {
	if (CalculateFogFactor(viewSpacePosition, FOG_POWER) >= 1.0) discard;
	
#if defined gbuffers_water
	if (abs(materialIDs - 4.0) < 0.5) { DoWaterFragment(); exit(); return; }
//	else discard;
#endif
	
	vec4 diffuse = GetDiffuse();
	
#if !defined gbuffers_water
	if (diffuse.a < 0.1000003) discard;
#endif
	
	vec4 normal      = GetNormal();
	vec2 specularity = GetSpecularity(normal.a, vertLightmap.t);	
	
	
	float encodedMaterialIDs = EncodeMaterialIDs(materialIDs, 1.0, materialIDs1.g, materialIDs1.b, materialIDs1.a);
	
	vec3 encode = vec3(Encode16(vec2(vertLightmap.st)), Encode16(vec2(specularity.r, encodedMaterialIDs)), 0.0);
	
	gl_FragData[0] = vec4(1.0, 0.0, 0.0, diffuse.a);
	gl_FragData[1] = vec4(diffuse.rgb, diffuse.a);
	gl_FragData[2] = vec4(EncodeNormal(normal.xyz), encode.r, 1.0);
	gl_FragData[3] = vec4(encode.g, 0.0, 0.0, 1.0);
	
	exit();
}
