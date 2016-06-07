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

uniform sampler2D colortex0;
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

varying mat4 shadowView;
#define shadowModelView shadowView

varying vec2 texcoord;

#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"
#include "/lib/DebugSetup.glsl"
#include "/lib/GlobalCompositeVariables.glsl"
#include "/lib/Masks.glsl"
#include "/lib/ShadingFunctions.fsh"


float GetDepth(in vec2 coord) {
	return texture2D(gdepthtex, coord).x;
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

vec3 ComputeGlobalIllumination(in vec4 position, in vec3 normal, const in float radius, in vec2 noise, in Mask mask) {
#ifdef GI_ENABLED
	float lightMult = 1.0;
	
	#ifdef GI_BOOST
		float normalShading = GetLambertianShading(normal, mask);
		
		float sunlight = ComputeDirectSunlight(position, normalShading);
		
		lightMult *= 1.0 - pow(sunlight, 1) * normalShading * 4.0;
		
		if (lightMult < 0.05) return vec3(0.0);
	#endif
	
	float LodCoeff = clamp(1.0 - length(position.xyz) / shadowDistance, 0.0, 1.0);
	
	float depthLOD	= 2.0 * LodCoeff * (GI_MODE == 1 ? 1.0 : 0.0);
	float sampleLOD	= 5.0 * LodCoeff * (GI_MODE == 1 ? 1.0 : 0.0);
	
	vec4 shadowViewPosition = shadowModelView * gbufferModelViewInverse * position;    // For linear comparisons (GI_MODE = 1)
	
	position = shadowProjection * shadowViewPosition; // "position" now represents shadow-projection-space position. Position can also be used for exponential comparisons (GI_MODE = 2)
	normal   = (shadowModelView * gbufferModelViewInverse * vec4(normal, 0.0)).xyz; // Convert the normal so it can be compared with the shadow normal samples
	normal  *= (GI_MODE == 1 ? vec3(-1.0) : vec3(-1.0, -1.0,  1.0));
	
	cfloat brightness = (GI_MODE == 1 ? 30.0 : 0.0001) * pow(radius, 2) * GI_BRIGHTNESS * SUN_LIGHT_LEVEL;
	cfloat scale      = radius / (GI_MODE == 1 ? 256.0 : 1024);
	
	vec3 GI = vec3(0.0);
	
	noise *= scale * (GI_MODE == 1 ? 0.0 : 1.0);
	
	#include "/lib/Samples/GI.glsl"
	
	for (int i = 0; i < GI_SAMPLE_COUNT; i++) {
		vec2 offset = samples[i] * scale + noise;
		
		vec4 samplePos = vec4(position.xy + offset, 0.0, 1.0);
		
		vec2 mapPos = BiasShadowMap(samplePos.xy) * 0.5 + 0.5;
		
		samplePos.z = texture2DLod(shadowtex1, mapPos, depthLOD).x;
		samplePos.z = samplePos.z * 8.0 - 4.0;    // Convert range from unsigned to signed and undo z-shrinking
		
	#if GI_MODE == 1
		samplePos = shadowProjectionInverse * samplePos; // Convert sample position to shadow-view-space for a linear comparison against the pixel's position
	#endif
		
		vec3 sampleDiff = (GI_MODE == 1 ? shadowViewPosition.xyz : position.xyz) - samplePos.xyz;
		
		float distanceCoeff = lengthSquared(sampleDiff) + (GI_MODE == 1 ? 0.0 : 0.0); // Inverse-square law
		      distanceCoeff = 1.0 / max(distanceCoeff, (GI_MODE == 1 ? pow(radius, 2) : 2.5e-4));
		
		vec3 sampleDir    = normalize(sampleDiff);
		vec3 shadowNormal = texture2DLod(shadowcolor1, mapPos, sampleLOD).xyz * 2.0 - 1.0;
		
		float viewNormalCoeff   = max0(dot(      normal, sampleDir));
		float shadowNormalCoeff = max0(dot(shadowNormal, sampleDir));
		
		viewNormalCoeff = viewNormalCoeff * (1.0 - GI_TRANSLUCENCE) + GI_TRANSLUCENCE;
		
	#if GI_MODE == 1
		shadowNormalCoeff = sqrt(shadowNormalCoeff);
	#endif
		
		vec3 flux = pow(texture2DLod(shadowcolor, mapPos, sampleLOD).rgb, vec3(2.2));
		
		GI += flux * viewNormalCoeff * shadowNormalCoeff * distanceCoeff;
	}
	
	GI /= GI_SAMPLE_COUNT;
	
	return GI * lightMult * brightness; // brightness is constant for all pixels for all samples. lightMult is not constant over all pixels, but is constant over each pixels' samples.
#else
	return vec3(0.0);
#endif
}

float ComputeVolumetricFog(in vec4 viewSpacePosition, in float noise) {
#ifdef VOLUMETRIC_FOG
	float fog    = 0.0;
	float weight = 0.0;
	
	float rayIncrement = gl_Fog.start / 64.0;
	vec3  rayStep      = normalize(viewSpacePosition.xyz + vec3(0.0, 0.0, noise));
	vec4  ray          = vec4(rayStep * gl_Fog.start, 1.0);
	
	mat4 ViewSpaceToShadowSpace = shadowProjection * shadowModelView * gbufferModelViewInverse; // Compose matrices outside of the loop to save computations
	
	while (length(ray) < length(viewSpacePosition.xyz)) {
		ray.xyz += rayStep * rayIncrement; // Increment raymarch
		
		vec3 samplePosition = BiasShadowProjection((ViewSpaceToShadowSpace * ray).xyz) * 0.5 + 0.5; // Convert ray to shadow-space, bias it, unsign it (reduce the range from [-1.0 to 1.0] to [0.0 to 1.0]) to convert it to lookup-coordinates
		
		fog += shadow2D(shadow, samplePosition).x * rayIncrement; // Increment fog
		
		weight += rayIncrement;
		
		rayIncrement *= 1.01; // Increase the step-size so that the sample-count decreases as the ray gets farther from the viewer
	}
	
	fog /= max(weight, 0.1e-8);
	fog  = pow(fog, VOLUMETRIC_FOG_POWER);
	
	return fog;
#else
	return 1.0;
#endif
}


void main() {
	float depth = GetDepth(texcoord);
	
	
	if (depth >= 1.0) { gl_FragData[0] = vec4(vec3(0.0), 1.0); exit(); return; }
	
	
	float depth1  = texture2D(depthtex1, texcoord).x;
	vec2  noise2D = GetDitherred2DNoise(texcoord * COMPOSITE0_SCALE, 2.0) * 2.0 - 1.0;
	
	vec4 viewSpacePosition = CalculateViewSpacePosition(texcoord, depth);
	
	
	vec3 encode; float torchLightmap, skyLightmap, smoothness; Mask mask;
	DecodeBuffer(texcoord, colortex0, encode, torchLightmap, skyLightmap, smoothness, mask.materialIDs);
	
	mask = AddWaterMask(CalculateMasks(mask), depth, depth1);
	
	
	float volFog = ComputeVolumetricFog(viewSpacePosition, noise2D.x);
	
	
	if (mask.transparent + mask.water> 0.5)
		{ gl_FragData[0] = vec4(vec3(0.0), volFog); exit(); return; }
	
	
	vec3 normal = GetNormal(texcoord);
	
	
	vec3 GI = ComputeGlobalIllumination(viewSpacePosition, normal, GI_RADIUS, noise2D, mask);
	
	
	gl_FragData[0] = vec4(pow(GI * 0.2, vec3(1.0 / 2.2)), volFog);
	
	exit();
}
