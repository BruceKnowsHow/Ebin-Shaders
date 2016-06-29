#version 410 compatibility
#define composite1
#define fsh
#define ShaderStage 1
#include "/lib/Syntax.glsl"

/* DRAWBUFFERS:576 */

const bool colortex7MipmapEnabled = true;

uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D colortex7;
uniform sampler2D gdepthtex;
uniform sampler2D depthtex1;
uniform sampler2D noisetex;
uniform sampler2D shadowtex1;
uniform sampler2DShadow shadow;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowProjection;

uniform vec3 cameraPosition;
uniform vec3 upPosition;

uniform float near;
uniform float far;

uniform float viewWidth;
uniform float viewHeight;

uniform int isEyeInWater;

varying mat4 shadowView;
#define shadowModelView shadowView

varying vec2 texcoord;

#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"
#include "/lib/DebugSetup.glsl"
#include "/lib/Uniform/GlobalCompositeVariables.glsl"
#include "/lib/Fragment/Masks.fsh"
#include "/lib/Misc/CalculateFogFactor.glsl"


vec3 GetDiffuse(in vec2 coord) {
	return texture2D(colortex5, coord).rgb;
}

float GetDepth(in vec2 coord) {
	return texture2D(gdepthtex, coord).x;
}

float GetTransparentDepth(in vec2 coord) {
	return texture2D(depthtex1, coord).x;
}

float ExpToLinearDepth(in float depth) {
	return 2.0 * near * (far + near - depth * (far - near));
}

vec4 CalculateViewSpacePosition(in vec2 coord, in float depth) {
	vec4 position  = gbufferProjectionInverse * vec4(vec3(coord, depth) * 2.0 - 1.0, 1.0);
	     position /= position.w;
	
	return position;
}

vec3 GetNormal(in vec2 coord) {
	return DecodeNormal(texture2D(colortex6, coord).xy);
}

#include "/lib/Misc/DecodeBuffer.fsh"


#include "/lib/Fragment/CalculateShadedFragment.fsh"

void BilateralUpsample(in vec3 normal, in float depth, out vec3 GI, out float volFog) {
	GI = vec3(0.0);
	volFog = 0.0;
	
#if (defined GI_ENABLED || defined VOLUMETRIC_FOG)
	depth = ExpToLinearDepth(depth);
	
	float totalWeights   = 0.0;
	float totalFogWeight = 0.0;
	
	cfloat kernal = 2.0;
	cfloat range = kernal - kernal * 0.5 - 0.5;
	
	
	for(float i = -range; i <= range; i++) {
		for(float j = -range; j <= range; j++) {
			vec2 offset = vec2(i, j) / vec2(viewWidth, viewHeight);
			
			float sampleDepth = ExpToLinearDepth(texture2D(gdepthtex, texcoord + offset * 8.0).x);
			
		#ifdef GI_ENABLED
			vec3  sampleNormal = GetNormal(texcoord + offset * 8.0);
			
			float weight  = 1.0 - abs(depth - sampleDepth);
			      weight *= dot(normal, sampleNormal);
			      weight  = pow(weight, 32);
			      weight  = max(1.0e-6, weight);
			
			GI += pow(texture2DLod(colortex7, texcoord * COMPOSITE0_SCALE + offset * 2.0, 1).rgb, vec3(2.2)) * weight;
			
			totalWeights += weight;
		#endif
			
		#ifdef VOLUMETRIC_FOG
			float FogWeight = 1.0 - abs(depth - sampleDepth) * 10.0;
			      FogWeight = pow(FogWeight, 32);
			      FogWeight = max(0.1e-8, FogWeight);
			
			volFog += texture2DLod(colortex7, texcoord * COMPOSITE0_SCALE + offset * 2.0, 1).a * FogWeight;
			
			totalFogWeight += FogWeight;
		#endif
		}
	}
	
	GI /= totalWeights;
	volFog /= totalFogWeight;
#endif
}


void main() {
	float depth0 = GetDepth(texcoord);
	
	if (depth0 >= 1.0) { discard; }
	
	
	vec3  diffuse =          GetDiffuse(texcoord);
	vec3  normal  =           GetNormal(texcoord);
	float depth1  = GetTransparentDepth(texcoord);
	
	vec4 viewSpacePosition0 = CalculateViewSpacePosition(texcoord, depth0);
	vec4 viewSpacePosition1 = CalculateViewSpacePosition(texcoord, depth1);
	
	
	vec3 encode; float torchLightmap, skyLightmap, smoothness; Mask mask;
	DecodeBuffer(texcoord, encode, torchLightmap, skyLightmap, smoothness, mask.materialIDs);
	
	mask = AddWaterMask(CalculateMasks(mask), depth0, depth1);
	
	encode.g = Encode16(vec2(smoothness, mask.materialIDs));
	
	
	vec4 dryViewSpacePosition = (mask.transparent > 0.5 ? viewSpacePosition1 : viewSpacePosition0);
	
	vec3 composite = CalculateShadedFragment(mask, torchLightmap, skyLightmap, normal, smoothness, dryViewSpacePosition);
	
	
	vec3 GI; float volFog;
	BilateralUpsample(normal, depth1, GI, volFog);
	
	composite += GI * sunlightColor * 5.0;
	
	
	composite *= pow(diffuse, vec3(2.2));
	
	
	gl_FragData[0] = vec4(EncodeColor(composite), 1.0);
	gl_FragData[1] = vec4(GI, volFog);
	gl_FragData[2] = vec4(EncodeNormal(normal), encode.rg);
	
	exit();
}
