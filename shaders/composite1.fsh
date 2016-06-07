#version 410 compatibility
#define composite1
#define fsh
#define ShaderStage 1
#include "/lib/Syntax.glsl"


/* DRAWBUFFERS:240 */

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
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
#include "/lib/GlobalCompositeVariables.glsl"
#include "/lib/Masks.glsl"
#include "/lib/ShadingFunctions.fsh"
#include "/lib/CalculateFogFactor.glsl"


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
	return DecodeNormal(texture2D(colortex1, coord).xy);
}

void DecodeBuffer(in vec2 coord, sampler2D buffer, out vec3 encode, out float buffer0r, out float buffer0g, out float buffer1r, out float buffer1g) {
	encode.rg = texture2D(buffer, texcoord).rg;
	
	vec2 buffer0 = Decode16(encode.r);
	buffer0r = buffer0.r;
	buffer0g = buffer0.g;
	
	vec2 buffer1 = Decode16(encode.g);
	buffer1r = buffer1.r;
	buffer1g = buffer1.g;
}

void BilateralUpsample(in vec3 normal, in float depth, in Mask mask, out vec3 GI, out float volFog) {
	GI = vec3(0.0);
	volFog = 0.0;
	
	if (mask.sky > 0.5) { volFog = 1.0; return; }
	
#if (defined GI_ENABLED || defined VOLUMETRIC_FOG)
	depth = ExpToLinearDepth(depth);
	
	float totalWeights   = 0.0;
	float totalFogWeight = 0.0;
	
	for(float i = -0.5; i <= 0.5; i++) {
		for(float j = -0.5; j <= 0.5; j++) {
			vec2 offset = vec2(i, j) / vec2(viewWidth, viewHeight);
			
			float sampleDepth = ExpToLinearDepth(texture2D(gdepthtex, texcoord + offset * 8.0).x);
			
		#ifdef GI_ENABLED
			vec3  sampleNormal = GetNormal(texcoord + offset * 8.0);
			
			float weight  = 1.0 - abs(depth - sampleDepth);
			      weight *= dot(normal, sampleNormal);
			      weight  = pow(weight, 32);
			      weight  = max(0.1e-8, weight);
			
			GI += pow(texture2D(colortex4, texcoord * COMPOSITE0_SCALE + offset).rgb, vec3(2.2)) * weight;
			
			totalWeights += weight;
		#endif
			
		#ifdef VOLUMETRIC_FOG
			float FogWeight = 1.0 - abs(depth - sampleDepth) * 10.0;
			      FogWeight = pow(FogWeight, 32);
			      FogWeight = max(0.1e-8, FogWeight);
			
			volFog += texture2D(colortex4, texcoord * COMPOSITE0_SCALE + offset).a * FogWeight;
			
			totalFogWeight += FogWeight;
		#endif
		}
	}
	
	GI /= totalWeights;
	volFog /= totalFogWeight;
#endif
}

#include "/lib/Sky.fsh"

float ComputeSkyAbsorbance(in vec4 viewSpacePosition, in vec4 viewSpacePosition1) {
	vec3 underwaterVector = viewSpacePosition.xyz - viewSpacePosition1.xyz;
	
	float UdotN = abs(dot(normalize(underwaterVector.xyz), normalize(upPosition)));
	
	float depth = length(underwaterVector.xyz) * UdotN;
	      depth = exp(-depth * 0.4);
	
	float fogFactor = CalculateFogFactor(viewSpacePosition1, 10.0);
	
	return 1.0 - clamp(depth - fogFactor, 0.0, 1.0);
}

void AddUnderwaterFog(inout vec3 color, in vec4 viewSpacePosition, in vec4 viewSpacePosition1, in float skyLightmap, in Mask mask) {
	vec3 waterVolumeColor = vec3(0.0, 0.01, 0.1) * skylightColor * pow(skyLightmap, 4.0);
	
	if (mask.water > 0.5)
		color = mix(color, waterVolumeColor, ComputeSkyAbsorbance(viewSpacePosition, viewSpacePosition1));
}


void main() {
	float depth = GetDepth(texcoord);
	
	
	vec3 color = texture2D(colortex2, texcoord).rgb;
	
	if (depth >= 1.0) { // Sky pixels are quickly composited and returned
		gl_FragData[0] = vec4((Deferred_Shading ? EncodeColor(color * 20.0) : color), 1.0); exit(); return; }
	
	
	color         = (Deferred_Shading ? color * 20.0 : DecodeColor(color));
	vec3  normal  =           GetNormal(texcoord);
	float depth1  = GetTransparentDepth(texcoord); // An appended 1 indicates that the variable is for a surface beneath first-layer transparency
	
	vec4 viewSpacePosition  = CalculateViewSpacePosition(texcoord, depth );
	vec4 viewSpacePosition1 = CalculateViewSpacePosition(texcoord, depth1);
	
	
	vec3 encode; float torchLightmap, skyLightmap, smoothness; Mask mask;
	DecodeBuffer(texcoord, colortex0, encode, torchLightmap, skyLightmap, smoothness, mask.materialIDs);
	
	mask = AddWaterMask(CalculateMasks(mask), depth, depth1);
	
	encode.g = Encode16(vec2(smoothness, mask.materialIDs));
	
	
#ifdef DEFERRED_SHADING
	vec4 dryViewSpacePosition = (mask.water > 0.5 ? viewSpacePosition1 : viewSpacePosition);
	
	vec3 composite = CalculateShadedFragment(color, mask, torchLightmap, skyLightmap, normal, smoothness, dryViewSpacePosition);
#else
	vec3 composite = color;
#endif
	
	
	vec3 GI; float volFog;
	BilateralUpsample(normal, depth, mask, GI, volFog);
	
	
	composite += GI * sunlightColor * pow(texture2D(colortex5, texcoord).rgb, vec3(2.2)) * 5.0;
	
	
	AddUnderwaterFog(composite, viewSpacePosition, viewSpacePosition1, skyLightmap, mask);
	
	
	gl_FragData[0] = vec4(EncodeColor(composite), 1.0);
	gl_FragData[1] = vec4(GI, volFog);
	gl_FragData[2] = vec4(encode.rgb, 1.0);
	
	exit();
}
