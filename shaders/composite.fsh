#version 410 compatibility
#define composite0
#define fsh
#define ShaderStage 0
#include "/lib/Syntax.glsl"


/* DRAWBUFFERS:4 */

const bool shadowtex1Mipmap    = true;
const bool shadowcolor0Mipmap  = true;
const bool shadowcolor1Mipmap  = true;

const bool shadowtex1Nearest   = true;
const bool shadowcolor0Nearest = false;
const bool shadowcolor1Nearest = false;

uniform sampler2D colortex1;
uniform sampler2D gdepthtex;
uniform sampler2D depthtex1;
uniform sampler2D noisetex;
uniform sampler2D shadowcolor;
uniform sampler2D shadowcolor1;
uniform sampler2D shadowtex1;
uniform sampler2DShadow shadow;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

uniform vec3 cameraPosition;

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


#define texture2DRaw(x, y) texelFetch(x, ivec2(y * vec2(viewWidth, viewHeight)), 0) // texture2DRaw bypasses downscaled interpolation, which causes issues with encoded buffers

float GetDepth(in vec2 coord) {
	return texture2DRaw(gdepthtex, coord).x;
}

vec4 CalculateViewSpacePosition(in vec2 coord, in float depth) {
	vec4 position  = gbufferProjectionInverse * vec4(vec3(coord, depth) * 2.0 - 1.0, 1.0);
	     position /= position.w;
	
	return position;
}

vec3 GetNormal(in vec2 coord) {
	return DecodeNormal(texture2DRaw(colortex1, coord).xy);
}

void DecodeBuffer(in vec2 coord, out vec3 encode, out float buffer0r, out float buffer0g, out float buffer1r, out float buffer1g) {
	encode.rg = texture2DRaw(colortex1, coord).ba;
	
	vec2 buffer0 = Decode16(encode.r);
	buffer0r = buffer0.r;
	buffer0g = buffer0.g;
	
	vec2 buffer1 = Decode16(encode.g);
	buffer1r = buffer1.r;
	buffer1g = buffer1.g;
}


#include "/lib/Misc/BiasFunctions.glsl"
#include "/lib/Fragment/Sunlight/GetSunlightShading.fsh"
#include "/lib/Fragment/Sunlight/ComputeHardShadows.fsh"

#if GI_MODE == 1
vec3 ComputeGlobalIllumination(in vec4 position, in vec3 normal, in float skyLightmap, const in float radius, in vec2 noise, in Mask mask) {
	#ifndef GI_ENABLED
		return vec3(0.0);
	#endif
	
	float lightMult = skyLightmap;
	
	#ifdef GI_BOOST
		float sunlight  = GetLambertianShading(normal, mask);
		      sunlight *= skyLightmap;
		      sunlight  = ComputeHardShadows(position, sunlight);
		
		lightMult = 1.0 - sunlight * 4.0;
	#endif
	
	if (lightMult < 0.05) return vec3(0.0);
	
	float LodCoeff = clamp(1.0 - length(position.xyz) / shadowDistance, 0.0, 1.0);
	
	float depthLOD	= 2.0 * LodCoeff;
	float sampleLOD	= 5.0 * LodCoeff;
	
	vec4 shadowViewPosition = shadowModelView * gbufferModelViewInverse * position;    // For linear comparisons (GI_MODE = 1)
	
	position = shadowProjection * shadowViewPosition; // "position" now represents shadow-projection-space position. Position can also be used for exponential comparisons (GI_MODE = 2)
	normal   = -(shadowModelView * gbufferModelViewInverse * vec4(normal, 0.0)).xyz; // Convert the normal so it can be compared with the shadow normal samples
	
	float  brightness = 12.5 * pow(radius, 2) * GI_BRIGHTNESS * SUN_LIGHT_LEVEL;
	cfloat scale      = radius / 256.0;
	
	vec3 GI = vec3(0.0);
	
	#include "/lib/Samples/GI.glsl"
	
	for (int i = 0; i < GI_SAMPLE_COUNT; i++) {
		vec2 offset = samples[i] * scale;
		
		vec4 samplePos = vec4(position.xy + offset, 0.0, 1.0);
		
		vec2 mapPos = BiasShadowMap(samplePos.xy) * 0.5 + 0.5;
		
		samplePos.z = texture2DLod(shadowtex1, mapPos, depthLOD).x;
		samplePos.z = samplePos.z * 8.0 - 4.0;    // Convert range from unsigned to signed and undo z-shrinking
		
		samplePos = shadowProjectionInverse * samplePos; // Convert sample position to shadow-view-space for a linear comparison against the pixel's position
		
		vec3 sampleDiff = shadowViewPosition.xyz - samplePos.xyz;
		
		float distanceCoeff = lengthSquared(sampleDiff); // Inverse-square law
		      distanceCoeff = 1.0 / max(distanceCoeff, pow(radius, 2));
		
		vec3 sampleDir = normalize(sampleDiff);
		
		vec3 shadowNormal;
		     shadowNormal.xy = texture2DLod(shadowcolor1, mapPos, sampleLOD).xy * 2.0 - 1.0;
		     shadowNormal.z  = sqrt(1.0 - lengthSquared(shadowNormal.xy));
		
		float viewNormalCoeff   = max0(dot(      normal, sampleDir));
		float shadowNormalCoeff = max0(dot(shadowNormal, sampleDir));
		
		viewNormalCoeff = viewNormalCoeff * (1.0 - GI_TRANSLUCENCE) + GI_TRANSLUCENCE;
		
		shadowNormalCoeff = sqrt(shadowNormalCoeff);
		
		vec3 flux = pow(texture2DLod(shadowcolor, mapPos, sampleLOD).rgb, vec3(2.2));
		
		GI += flux * viewNormalCoeff * shadowNormalCoeff * distanceCoeff;
	}
	
	GI /= GI_SAMPLE_COUNT;
	
	return GI * lightMult * brightness; // brightness is constant for all pixels for all samples. lightMult is not constant over all pixels, but is constant over each pixels' samples.
}

#elif GI_MODE == 2
vec3 ComputeGlobalIllumination(in vec4 position, in vec3 normal, in float skyLightmap, const in float radius, in vec2 noise, in Mask mask) {
	#ifndef GI_ENABLED
		return vec3(0.0);
	#endif
	
	float lightMult = skyLightmap;
	
	#ifdef GI_BOOST
		float sunlight  = GetLambertianShading(normal, mask);
		      sunlight *= skyLightmap;
		      sunlight  = ComputeHardShadows(position, sunlight);
		
		lightMult = 1.0 - sunlight * 4.0;
	#endif
	
	if (lightMult < 0.05) return vec3(0.0);
	
	float LodCoeff = clamp(1.0 - length(position.xyz) / shadowDistance, 0.0, 1.0);
	
	float depthLOD	= 2.0 * LodCoeff * 1.0;
	float sampleLOD	= 5.0 * LodCoeff * 1.0;
	
	vec4 shadowViewPosition = shadowModelView * gbufferModelViewInverse * position;    // For linear comparisons (GI_MODE = 1)
	
	position = shadowProjection * shadowViewPosition; // "position" now represents shadow-projection-space position. Position can also be used for exponential comparisons (GI_MODE = 2)
	normal   = -(shadowModelView * gbufferModelViewInverse * vec4(normal, 0.0)).xyz; // Convert the normal so it can be compared with the shadow normal samples
	
	
	float biasCoeff = GetShadowBias(position.xy);
	
	float  brightness = 100.0 * pow(radius, sqrt(2.0)) * GI_BRIGHTNESS * SUN_LIGHT_LEVEL;
	cfloat scale      = radius / 256.0;
	
	vec3 GI = vec3(0.0);
	
	noise *= scale;
	
	for(float x = -1.0; x <= 1.0; x += 1.0 / 4.0) {
		for(float y = -1.0; y <= 1.0; y += 1.0 / 4.0) {
			vec2 offset = (vec2(y, x) + noise) * scale;
			if (offset.x == 0.0 && offset.y == 0.0) continue; 
			
			vec4 samplePos = vec4(position.xy + offset, position.zw);
			
			vec2 mapPos = BiasShadowMap(samplePos.xy) * 0.5 + 0.5;
			
			samplePos.z = texture2DLod(shadowtex1, mapPos, depthLOD).x;
			samplePos.z = samplePos.z * 8.0 - 4.0; // Convert range from unsigned to signed and undo z-shrinking
			
			samplePos = shadowProjectionInverse * samplePos; // Convert sample position to shadow-view-space for a linear comparison against the pixel's position
			
			vec3 sampleDiff = shadowViewPosition.xyz - samplePos.xyz;
			
			float distanceCoeff = lengthSquared(sampleDiff);
			
			vec3 sampleDir = normalize(sampleDiff);
			
			vec3 shadowNormal;
			     shadowNormal.xy = texture2DLod(shadowcolor1, mapPos, sampleLOD).xy * 2.0 - 1.0;
			     shadowNormal.z  = sqrt(1.0 - lengthSquared(shadowNormal.xy));
			
			float viewNormalCoeff   = max0(dot(      normal, sampleDir));
			float shadowNormalCoeff = max0(dot(shadowNormal, sampleDir));
			
			viewNormalCoeff = viewNormalCoeff * (1.0 - GI_TRANSLUCENCE) + GI_TRANSLUCENCE;
			
			vec3 flux = pow(texture2DLod(shadowcolor, mapPos, sampleLOD).rgb, vec3(2.2));
			
			float sampleCoeff = viewNormalCoeff * shadowNormalCoeff;
				  sampleCoeff = pow(sampleCoeff, 1.0 + 4.0 - 4.0 * min1(distanceCoeff));
			
			GI += flux * sampleCoeff / max(distanceCoeff, 1.0) * 0.2;
			GI += flux * sampleCoeff / max(distanceCoeff, pow(radius, 2)) * 0.5;
		}
	}
	
	GI /= pow2(2.0 * 4.0 + 1.0);
	
	return GI * lightMult * brightness; // brightness is constant for all pixels for all samples. lightMult is not constant over all pixels, but is constant over each pixels' samples.
}

#else
vec3 ComputeGlobalIllumination(in vec4 position, in vec3 normal, in float skyLightmap, const in float radius, in vec2 noise, in Mask mask) {
	#ifndef GI_ENABLED
		return vec3(0.0);
	#endif
	
	float lightMult = skyLightmap;
	
	#ifdef GI_BOOST
		float sunlight  = GetLambertianShading(normal, mask);
		      sunlight *= skyLightmap;
		      sunlight  = ComputeHardShadows(position, sunlight);
		
		lightMult = 1.0 - sunlight * 4.0;
	#endif
	
	if (lightMult < 0.05) return vec3(0.0);
	
	float LodCoeff = clamp(1.0 - length(position.xyz) / shadowDistance, 0.0, 1.0);
	
	float depthLOD	= 2.0 * LodCoeff * 0.0;
	float sampleLOD	= 5.0 * LodCoeff * 0.0;
	
	vec4 shadowViewPosition = shadowModelView * gbufferModelViewInverse * position;    // For linear comparisons (GI_MODE = 1)
	
	position = shadowProjection * shadowViewPosition; // "position" now represents shadow-projection-space position. Position can also be used for exponential comparisons (GI_MODE = 2)
	normal   = vec3(-1.0, -1.0,  1.0) * (shadowModelView * gbufferModelViewInverse * vec4(normal, 0.0)).xyz; // Convert the normal so it can be compared with the shadow normal samples
	
	float  brightness = 0.000075 * pow(radius, 2) * GI_BRIGHTNESS * SUN_LIGHT_LEVEL;
	cfloat scale      = radius / 1024.0;
	
	vec3 GI = vec3(0.0);
	
	noise *= scale;
	
	#include "/lib/Samples/GI.glsl"
	
	for (int i = 0; i < GI_SAMPLE_COUNT; i++) {
		vec2 offset = samples[i] * scale + noise;
		
		vec4 samplePos = vec4(position.xy + offset, 0.0, 1.0);
		
		vec2 mapPos = BiasShadowMap(samplePos.xy) * 0.5 + 0.5;
		
		samplePos.z = texture2DLod(shadowtex1, mapPos, depthLOD).x;
		samplePos.z = samplePos.z * 8.0 - 4.0;    // Convert range from unsigned to signed and undo z-shrinking
		
		vec3 sampleDiff = position.xyz - samplePos.xyz;
		
		float distanceCoeff = lengthSquared(sampleDiff); // Inverse-square law
		      distanceCoeff = 1.0 / max(distanceCoeff, 2.5e-4);
		
		vec3 sampleDir = normalize(sampleDiff);
		
		vec3 shadowNormal;
		     shadowNormal.xy = texture2DLod(shadowcolor1, mapPos, sampleLOD).xy * 2.0 - 1.0;
		     shadowNormal.z  = -sqrt(1.0 - lengthSquared(shadowNormal.xy));
		
		float viewNormalCoeff   = max0(dot(      normal, sampleDir));
		float shadowNormalCoeff = max0(dot(shadowNormal, sampleDir));
		
		viewNormalCoeff = viewNormalCoeff * (1.0 - GI_TRANSLUCENCE) + GI_TRANSLUCENCE;
		
		vec3 flux = pow(texture2DLod(shadowcolor, mapPos, sampleLOD).rgb, vec3(2.2));
		
		GI += flux * viewNormalCoeff * shadowNormalCoeff * distanceCoeff;
	}
	
	GI /= GI_SAMPLE_COUNT;
	
	return GI * lightMult * brightness; // brightness is constant for all pixels for all samples. lightMult is not constant over all pixels, but is constant over each pixels' samples.
}
#endif

float ComputeVolumetricFog(in vec4 viewSpacePosition) {
#ifdef VOLUMETRIC_FOG
	float fog    = 0.0;
	float weight = 0.0;
	
	float rayIncrement = gl_Fog.start / 64.0;
	vec3  rayStep      = normalize(viewSpacePosition.xyz);
	vec4  ray          = vec4(rayStep * gl_Fog.start, 1.0);
	
	mat4 ViewSpaceToShadowSpace = shadowProjection * shadowModelView * gbufferModelViewInverse; // Compose matrices outside of the loop to save computations
	
	while (length(ray) < length(viewSpacePosition.xyz)) {
		ray.xyz += rayStep * rayIncrement; // Increment raymarch
		
		vec3 samplePosition = BiasShadowProjection((ViewSpaceToShadowSpace * ray).xyz) * 0.5 + 0.5; // Convert ray to shadow-space, bias it, unsign it (reduce the range from [-1.0 to 1.0] to [0.0 to 1.0]) to convert it to lookup-coordinates
		
		fog += shadow2D(shadow, samplePosition).x * rayIncrement; // Increment fog
		
		weight += rayIncrement;
		
		rayIncrement *= 1.01; // Increase the step-size so that the sample-count decreases as the ray gets farther from the viewer
	}
	
	fog /= max(weight, 1.0e-9);
	fog  = pow(fog, VOLUMETRIC_FOG_POWER);
	
	return fog;
#else
	return 1.0;
#endif
}


void main() {
	float depth = GetDepth(texcoord);
	
	if (depth >= 1.0) { discard; }
	
	
	float depth1 = texture2DRaw(depthtex1, texcoord).x;
	
#ifdef COMPOSITE0_NOISE
	vec2 noise2D = GetDitherred2DNoise(texcoord * COMPOSITE0_SCALE, 4.0) * 2.0 - 1.0;
#else
	vec2 noise2D = vec2(0.0);
#endif
	
	vec4 viewSpacePosition = CalculateViewSpacePosition(texcoord, depth);
	
	
	vec3 encode; float torchLightmap, skyLightmap, smoothness; Mask mask;
	DecodeBuffer(texcoord, encode, torchLightmap, skyLightmap, smoothness, mask.materialIDs);
	
	mask = AddWaterMask(CalculateMasks(mask), depth, depth1);
	show(mask.transparent);
	
	float volFog = ComputeVolumetricFog(viewSpacePosition);
	
	
	if (mask.transparent + float(isEyeInWater != mask.water) > 0.5)
		{ gl_FragData[0] = vec4(vec3(0.0), volFog); exit(); return; }
	
	
	vec3 normal = GetNormal(texcoord);
	
	
	vec3 GI = ComputeGlobalIllumination(viewSpacePosition, normal, skyLightmap, GI_RADIUS, noise2D, mask);
	
	
	gl_FragData[0] = vec4(pow(GI * 0.2, vec3(1.0 / 2.2)), volFog);
	
	exit();
}