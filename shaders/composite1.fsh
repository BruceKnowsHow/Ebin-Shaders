#version 120
#define composite1_fsh true
#define ShaderStage 1

/* DRAWBUFFERS:24 */

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D gdepthtex;
uniform sampler2D depthtex1;
uniform sampler2D noisetex;
uniform sampler2D shadowtex1;
uniform sampler2DShadow shadow;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowProjection;

uniform vec3 cameraPosition;

uniform float near;
uniform float far;

uniform float viewWidth;
uniform float viewHeight;

varying mat4 shadowView;
#define shadowModelView shadowView

varying vec2 texcoord;

#include "/lib/Settings.glsl"
#include "/lib/Util.glsl"
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

float GetSmoothness(in vec2 coord) {
	return texture2D(colortex0, texcoord).b;
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
	return DecodeNormal(texture2D(colortex0, coord).xy);
}

void GetColortex3(in vec2 coord, out vec3 tex3, out float buffer0r, out float buffer0g, out float buffer0b, out vec3 buffer1) {
	tex3.r = texture2D(colortex3, texcoord).r;
	tex3.g = texture2D(colortex3, texcoord).g;
	
	Decode32to8(tex3.r, buffer0r, buffer0g  , buffer0b);
	Decode32to8(tex3.g, buffer1.r, buffer1.g, buffer1.b);
}

void BilateralUpsample(in vec3 normal, in float depth, in Mask mask, out vec3 GI, out float volFog) {
	GI = vec3(0.0);
	volFog = 0.0;
	
	if (mask.sky > 0.5) { volFog = 1.0; return; }
	
	depth = ExpToLinearDepth(depth);
	
	float totalWeights   = 0.0;
	float totalFogWeight = 0.0;
	
	for(float i = -0.5; i <= 0.5; i++) {
		for(float j = -0.5; j <= 0.5; j++) {
			vec2 offset = vec2(i, j) / vec2(viewWidth, viewHeight);
			
			float sampleDepth  = ExpToLinearDepth(texture2D(gdepthtex, texcoord + offset * 8.0).x);
			vec3  sampleNormal = GetNormal(texcoord + offset * 8.0);
			
			float weight  = 1.0 - abs(depth - sampleDepth);
			      weight *= dot(normal, sampleNormal);
			      weight  = pow(weight, 32);
			      weight  = max(0.1e-8, weight);
			
			float FogWeight = 1.0 - abs(depth - sampleDepth) * 10.0;
			      FogWeight = pow(FogWeight, 32);
			      FogWeight = max(0.1e-8, FogWeight);
			
			GI  += DecodeColor(texture2D(colortex4, texcoord * COMPOSITE0_SCALE + offset).rgb) * weight;
			volFog += texture2D(colortex4, texcoord * COMPOSITE0_SCALE + offset).a * FogWeight;
			
			totalWeights   += weight;
			totalFogWeight += FogWeight;
		}
	}
	
	GI  /= totalWeights;
	volFog /= totalFogWeight;
}

#include "/lib/Sky.fsh"

float ComputeSkyAbsorbance(in vec4 viewSpacePosition, in vec4 viewSpacePosition1, in vec3 normal) {
	vec3 underwaterVector = viewSpacePosition.xyz - viewSpacePosition1.xyz;
	
	float UdotN = abs(dot(normalize(underwaterVector.xyz), normal));
	
	float depth = length(underwaterVector.xyz) * UdotN;
	      depth = exp(-depth * 0.35);
	
	float fogFactor = CalculateFogFactor(viewSpacePosition1, 10.0);
	
	return 1.0 - clamp(depth - fogFactor, 0.0, 1.0);
}

void AddUnderwaterFog(inout vec3 color, in vec4 viewSpacePosition, in vec4 viewSpacePosition1, in vec3 normal, in Mask mask) {
	vec3 waterVolumeColor = vec3(0.0, 0.01, 0.1) * colorSkylight;
	
	if (mask.water > 0.5)
		color = mix(color, waterVolumeColor, ComputeSkyAbsorbance(viewSpacePosition, viewSpacePosition1, normal));
}


void main() {
	// Sky pixels are swiftly calculated and returned
	float depth = GetDepth(texcoord);
	vec4  viewSpacePosition = CalculateViewSpacePosition(texcoord, depth);
	
	if (depth >= 1.0) {
		gl_FragData[0] = vec4(EncodeColor(CalculateSky(viewSpacePosition)), 1.0); exit(); return; }
	
	
	vec3 tex3; float torchLightmap, skyLightmap; Mask mask; vec3 diffuse;
	
	GetColortex3(texcoord, tex3, torchLightmap, skyLightmap, mask.matIDs, diffuse);
	
	CalculateMasks(mask);
	
	
	vec3  normal     =           GetNormal(texcoord);
	float smoothness =       GetSmoothness(texcoord);
	float depth1     = GetTransparentDepth(texcoord); // An appended 1 indicates that the variable is for a surface beneath first-layer transparency
	
	vec4  viewSpacePosition1 = CalculateViewSpacePosition(texcoord, depth1);
	
#ifdef DEFERRED_SHADING
	vec3 composite = CalculateShadedFragment(diffuse, mask, torchLightmap, skyLightmap, normal, smoothness, viewSpacePosition);
#else
	vec3 composite = DecodeColor(texture2D(colortex2, texcoord).rgb);
#endif
	
	
	vec3 GI; float volFog;
	BilateralUpsample(normal, depth, mask, GI, volFog);
	
	composite += GI * colorSunlight * pow(diffuse, vec3(2.2));
	
	AddUnderwaterFog(composite, viewSpacePosition, viewSpacePosition1, normal, mask);
	
	gl_FragData[0] = vec4(EncodeColor(composite), 1.0);
	gl_FragData[1] = vec4(EncodeColor(GI), volFog);
	
	exit();
}
