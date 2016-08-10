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

#include "/lib/Fragment/Global_Illumination.fsh"

#include "lib/Fragment/Ambient_Occlusion.fsh"


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
	
	Mask mask = CalculateMasks(Decode16(texture2D(colortex5, texcoord).r).g);
	
	if (depth0 != depth1) {
		mask.transparent = 1.0;
		mask.water       = float(texture2D(colortex0, texcoord).r >= 0.5);
	}
	
	vec3 normal = DecodeNormal(texture2D(colortex4, texcoord).xy);
	
	
	float AO = CalculateSSAO(viewSpacePosition0, normal);
	
	
	if (depth1 >= 1.0 || isEyeInWater != mask.water)
		{ gl_FragData[0] = vec4(vec3(0.0), AO); exit(); return; }
	
	
	vec3 GI = ComputeGlobalIllumination(viewSpacePosition1, normal, skyLightmap, GI_RADIUS * 2.0, noise2D, mask);
	
	
	gl_FragData[0] = vec4(pow(GI * 0.2, vec3(1.0 / 2.2)), AO);
	
	exit();
}
