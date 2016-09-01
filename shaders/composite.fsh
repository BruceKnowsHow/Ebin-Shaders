#version 410 compatibility
#define composite0
#define fsh
#define ShaderStage 0
#include "/lib/Syntax.glsl"

/* DRAWBUFFERS:6 */

const bool shadowtex1Mipmap    = true;
const bool shadowcolor0Mipmap  = true;
const bool shadowcolor1Mipmap  = true;

const bool shadowtex1Nearest   = true;
const bool shadowcolor0Nearest = false;
const bool shadowcolor1Nearest = false;

uniform sampler2D colortex0;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
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

uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;

uniform int isEyeInWater;

varying vec2 texcoord;

#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"
#include "/lib/Debug.glsl"
#include "/lib/Uniform/Global_Composite_Variables.glsl"
#include "/lib/Fragment/Masks.fsh"

#define texture2DRaw(x, y) texelFetch(x, ivec2(y * vec2(viewWidth, viewHeight)), 0) // texture2DRaw bypasses downscaled interpolation, which causes issues with encoded buffers

float GetDepth(vec2 coord) {
	return texture2DRaw(gdepthtex, coord).x;
}

float GetDepthLinear(vec2 coord) {	
	return (near * far) / (texture2DRaw(gdepthtex, coord).x * (near - far) + far);
}

vec4 CalculateViewSpacePosition(vec2 coord, float depth) {
	vec4 position  = gbufferProjectionInverse * vec4(vec3(coord, depth) * 2.0 - 1.0, 1.0);
	     position /= position.w;
	
	return position;
}

vec3 GetNormal(vec2 coord) {
	return DecodeNormal(texture2DRaw(colortex4, coord).xy);
}


vec2 GetDitherred2DNoise(vec2 coord, float n) { // Returns a random noise pattern ranging {-1.0 to 1.0} that repeats every n pixels
	coord *= vec2(viewWidth, viewHeight);
	coord  = mod(coord, vec2(n));
	coord /= noiseTextureResolution;
	return texture2D(noisetex, coord).xy;
}

#include "/lib/Misc/Bias_Functions.glsl"
#include "/lib/Fragment/Sunlight/GetSunlightShading.fsh"
#include "/lib/Fragment/Sunlight/ComputeHardShadows.fsh"

#ifndef GI_ENABLED
	#define ComputeGlobalIllumination(a, b, c, d, e, f) vec3(0.0)
#elif GI_MODE == 1
vec3 ComputeGlobalIllumination(vec4 position, vec3 normal, float skyLightmap, const float radius, vec2 noise, Mask mask) {
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
		
		viewNormalCoeff = mix(viewNormalCoeff, 1.0, GI_TRANSLUCENCE);
		
		shadowNormalCoeff = sqrt(shadowNormalCoeff);
		
		vec3 flux = pow(texture2DLod(shadowcolor, mapPos, sampleLOD).rgb, vec3(2.2));
		
		GI += flux * viewNormalCoeff * shadowNormalCoeff * distanceCoeff;
	}
	
	GI /= GI_SAMPLE_COUNT;
	
	return GI * lightMult * brightness; // brightness is constant for all pixels for all samples. lightMult is not constant over all pixels, but is constant over each pixels' samples.
}
#endif

void main() {
	float depth0 = GetDepth(texcoord);
	
	if (depth0 >= 1.0) { discard; }
	
	
#ifdef COMPOSITE0_NOISE
	vec2 noise2D = GetDitherred2DNoise(texcoord * COMPOSITE0_SCALE, 4.0) * 2.0 - 1.0;
#else
	vec2 noise2D = vec2(0.0);
#endif
	
	
	vec2  buffer0     = Decode16(texture2D(colortex4, texcoord).b);
	float smoothness  = buffer0.r;
	float skyLightmap = buffer0.g;
	
	Mask mask = CalculateMasks(Decode16(texture2D(colortex5, texcoord).r).g);
	
	float depth1 = (mask.hand > 0.5 ? depth0 : texture2DRaw(depthtex1, texcoord).x);
	
	vec4 viewSpacePosition0 = CalculateViewSpacePosition(texcoord, depth0);
	vec4 viewSpacePosition1 = CalculateViewSpacePosition(texcoord, depth1);
	
	if (depth0 != depth1) {
		mask.transparent = 1.0;
		mask.water       = float(texture2D(colortex0, texcoord).r >= 0.5);
	}
	
	vec3 normal = DecodeNormal(texture2D(colortex4, texcoord).xy);
	
	
	if (depth1 >= 1.0 || isEyeInWater != mask.water)
		{ gl_FragData[0] = vec4(vec3(0.0), 1.0); exit(); return; }
	
	
	vec3 GI = ComputeGlobalIllumination(viewSpacePosition1, normal, skyLightmap, GI_RADIUS * 2.0, noise2D, mask);
	
	
	gl_FragData[0] = vec4(pow(GI * 0.2, vec3(1.0 / 2.2)), 1.0);
	
	exit();
}
