/* DRAWBUFFERS:0123456 */

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D noisetex;

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

varying float tbnIndex;

#include "/lib/Misc/MenuInitializer.glsl"
#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"
#include "/lib/DebugSetup.glsl"
#include "/lib/Misc/CalculateFogFactor.glsl"
#include "/lib/Fragment/Masks.fsh"

#if defined gbuffers_water
#include "/lib/Uniform/GlobalCompositeVariables.glsl"
#include "/lib/Fragment/CalculateShadedFragment.fsh"
#endif


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
	
	normal.xyz = normalize((normal.xyz * 2.0 - 1.0) * transpose(tbnMatrix));
	
	return normal;
}

vec3 GetTangentNormal() {
#ifdef NORMAL_MAPS
	return texture2D(normals, texcoord).rgb;
#else
	return vec3(0.5, 0.5, 1.0);
#endif
}

void DoWaterFragment() {
	gl_FragData[0] = vec4(EncodeNormal(transpose(tbnMatrix)[2]), 0.0, 1.0);
	gl_FragData[1] = vec4(0.0);
	gl_FragData[2] = vec4(0.0);
}

vec2 GetSpecularity(in float height, in float skyLightmap) {
#ifdef SPECULARITY_MAPS
	vec2 specular = texture2D(specular, texcoord).rg;
	
	float smoothness = specular.r;
	float metalness = specular.g;
	
	float wetfactor = wetness * pow(skyLightmap, 10.0);
	
	smoothness *= 1.0 + wetfactor;
	smoothness += (wetfactor - 0.5) * wetfactor;
	smoothness += (1.0 - height) * 0.5 * wetfactor;
	
	smoothness = clamp01(smoothness);
	
	return vec2(smoothness, metalness);
#else
	return vec2(0.0);
#endif
}

vec2 EncodeNormalData(in vec3 normalTexture, in float tbnIndex) {
	vec2 encode;
	
	encode.r = tbnIndex / 8.0;
	encode.g = Encode16(normalTexture.xy);
	
	return encode;
}


void main() {
	if (CalculateFogFactor(viewSpacePosition, FOG_POWER) >= 1.0) discard;
	
	vec4 diffuse = GetDiffuse();
	
	if (diffuse.a < 0.1000003) discard;
	
	
	vec4 normal = GetNormal();
	vec2 specularity = GetSpecularity(normal.a, vertLightmap.t);	
	
	
#if !defined gbuffers_water
	float encodedMaterialIDs = EncodeMaterialIDs(materialIDs, specularity.g, materialIDs1.g, materialIDs1.b, materialIDs1.a);
	
	vec2 encode = vec2(Encode16(vec2(vertLightmap.st)), Encode16(vec2(specularity.r, encodedMaterialIDs)));
	
	gl_FragData[0] = vec4(0.0, 0.0, 0.0, 1.0);
	gl_FragData[1] = vec4(0.0, 0.0, 0.0, 1.0);
	gl_FragData[2] = vec4(0.0, 0.0, 0.0, 1.0);
	gl_FragData[3] = vec4(0.0, 0.0, 0.0, 1.0);
	gl_FragData[4] = vec4(0.0, 0.0, 0.0, 1.0);
	gl_FragData[5] = vec4(diffuse.rgb, 1.0);
	gl_FragData[6] = vec4(EncodeNormal(normal.xyz), encode.rg);
#else
	specularity.r = mix(specularity.r, 0.85, abs(mcID - 8.5) < 0.6);
	
	vec2 encode = vec2(Encode16(vec2(vertLightmap.st)), Encode16(vec2(specularity.r, 0.0)));
	
	vec2 encodedNormal = EncodeNormalData(GetTangentNormal(), tbnIndex);
	
	Mask mask;
	
	vec3 composite  = CalculateShadedFragment(mask, vertLightmap.r, vertLightmap.g, normal.xyz, specularity.r, viewSpacePosition);
	     composite *= pow(diffuse.rgb, vec3(2.2));
	
	gl_FragData[0] = vec4(encodedNormal, 0.0, 1.0);
	gl_FragData[1] = vec4(abs(mcID - 8.5) < 0.6, 0.0, 0.0, 1.0);
	gl_FragData[2] = vec4(encode.rg, 0.0, 1.0);
	gl_FragData[3] = vec4(composite * 0.2, diffuse.a);
	gl_FragData[4] = vec4(1.0, 0.0, 0.0, diffuse.a);
	gl_FragData[5] = vec4(0.0);
#endif
	
	exit();
}
