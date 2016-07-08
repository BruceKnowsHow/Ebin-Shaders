#version 410 compatibility
#define composite0
#define fsh
#define ShaderStage 0
#include "/lib/Syntax.glsl"


/* DRAWBUFFERS:56 */

const bool shadowtex1Mipmap    = true;
const bool shadowcolor0Mipmap  = true;
const bool shadowcolor1Mipmap  = true;

const bool shadowtex1Nearest   = true;
const bool shadowcolor0Nearest = false;
const bool shadowcolor1Nearest = false;

uniform sampler2D colortex0;
uniform sampler2D colortex4;
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
#include "/lib/DebugSetup.glsl"
#include "/lib/Uniform/GlobalCompositeVariables.glsl"
#include "/lib/Fragment/Masks.fsh"


#define texture2DRaw(x, y) texelFetch(x, ivec2(y * vec2(viewWidth, viewHeight)), 0) // texture2DRaw bypasses downscaled interpolation, which causes issues with encoded buffers

float GetDepth(in vec2 coord) {
	return texture2DRaw(gdepthtex, coord).x;
}

float GetDepthLinear(in vec2 coord) {	
	return (near * far) / (texture2DRaw(gdepthtex, coord).x * (near - far) + far);
}

vec4 CalculateViewSpacePosition(in vec2 coord, in float depth) {
	vec4 position  = gbufferProjectionInverse * vec4(vec3(coord, depth) * 2.0 - 1.0, 1.0);
	     position /= position.w;
	
	return position;
}

vec3 GetNormal(in vec2 coord) {
	return DecodeNormal(texture2DRaw(colortex4, coord).xy);
}


vec2 GetDitherred2DNoise(in vec2 coord, in float n) { // Returns a random noise pattern ranging {-1.0 to 1.0} that repeats every n pixels
	coord *= vec2(viewWidth, viewHeight);
	coord  = mod(coord, vec2(n));
	coord /= noiseTextureResolution;
	return texture2D(noisetex, coord).xy;
}

#include "/lib/Misc/BiasFunctions.glsl"
#include "/lib/Fragment/Sunlight/GetSunlightShading.fsh"
#include "/lib/Fragment/Sunlight/ComputeHardShadows.fsh"

#include "/lib/Fragment/GlobalIllumination.fsh"

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

#include "lib/Fragment/AO.fsh"

void main() {
	float depth0 = GetDepth(texcoord);
	
	if (depth0 >= 1.0) { discard; }
	
	
	float depth1 = texture2DRaw(depthtex1, texcoord).x;
	
#ifdef COMPOSITE0_NOISE
	vec2 noise2D = GetDitherred2DNoise(texcoord * COMPOSITE0_SCALE, 4.0) * 2.0 - 1.0;
#else
	vec2 noise2D = vec2(0.0);
#endif
	
	vec4 viewSpacePosition0 = CalculateViewSpacePosition(texcoord, depth0);
	vec4 viewSpacePosition1 = CalculateViewSpacePosition(texcoord, depth0);
	
	
	vec2  buffer0     = Decode16(texture2D(colortex4, texcoord).b);
	float smoothness  = buffer0.r;
	float skyLightmap = buffer0.g;
	
	Mask mask = CalculateMasks(Decode16(texture2D(colortex4, texcoord).a).g);
	
	if (depth0 != depth1) {
		mask.transparent = 1.0;
		mask.water   = float(texture2D(colortex0, texcoord).r >= 0.5);
	}
	
	vec3 normal = DecodeNormal(texture2D(colortex4, texcoord).xy);
	
	
	float volFog = ComputeVolumetricFog(viewSpacePosition0);
	
	
	if (depth1 >= 1.0 || isEyeInWater != mask.water)
		{ gl_FragData[0] = vec4(vec3(0.0), volFog); exit(); return; }
	
	
	vec3 GI = ComputeGlobalIllumination(viewSpacePosition1, normal, skyLightmap, GI_RADIUS * 2.0, noise2D, mask);
	float AO = CalculateSSAO(viewSpacePosition0, normal);
	GI *= AO;
	
	
	gl_FragData[0] = vec4(pow(GI * 0.2, vec3(1.0 / 2.2)), AO);
	gl_FragData[1] = vec4(volFog, 0.0, 0.0, 1.0);
	
	exit();
}
