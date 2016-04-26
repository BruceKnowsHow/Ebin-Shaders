#version 120

/* DRAWBUFFERS:24 */

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex6;
uniform sampler2D gdepthtex;
uniform sampler2D depthtex1;
uniform sampler2D shadowcolor;
uniform sampler2DShadow shadow;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelViewInverse;

uniform vec3 cameraPosition;
uniform vec3 upPosition;

uniform float viewWidth;
uniform float viewHeight;
uniform float near;
uniform float far;

varying vec2 texcoord;

#include "/lib/Settings.glsl"
#include "/lib/Util.glsl"
#include "/lib/Encoding.glsl"
#include "/lib/GlobalCompositeVariables.fsh"
#include "/lib/Masks.glsl"
#include "/lib/ShadingFunctions.fsh"
#include "/lib/CalculateFogFactor.glsl"


vec3 GetDiffuse(in vec2 coord) {
	return texture2D((Deferred_Shading ? colortex2 : colortex6), coord).rgb;
}

vec3 GetDiffuseForward(in vec2 coord) {
	return texture2D(colortex6, coord).rgb;
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
	return DecodeNormal(texture2D(colortex0, coord).xy);
}

float GetMaterialID(in vec2 coord) {
	return texture2D(colortex3, texcoord).b;
}

float GetTorchLightmap(in vec2 coord) {
	return texture2D(colortex3, texcoord).r;
}

float GetSkyLightmap(in vec2 coord) {
	return texture2D(colortex3, texcoord).g;
}

void BilateralUpsample(in vec3 normal, in float depth, in Mask mask, out vec3 GI, out float Fog) {
	GI = vec3(0.0);
	Fog = 0.0;
	
	if (mask.sky > 0.5) { Fog = 1.0; return; }
	
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
			      weight  = max(0.000000001, weight);
			
			float FogWeight = 1.0 - abs(depth - sampleDepth) * 10.0;
			      FogWeight = pow(FogWeight, 32);
			      FogWeight = max(0.000000001, FogWeight);
			
			GI  += DecodeColor(texture2D(colortex4, texcoord * COMPOSITE0_SCALE + offset).rgb) * weight;
			Fog += texture2D(colortex4, texcoord * COMPOSITE0_SCALE + offset).a * FogWeight;
			
			totalWeights   += weight;
			totalFogWeight += FogWeight;
		}
	}
	
	GI  /= totalWeights;
	Fog /= totalFogWeight;
}

#include "/lib/Sky.fsh"

float ComputeSkyAbsorbance(in vec4 viewSpacePosition, in vec4 viewSpacePosition1, in vec3 normal) {
	vec3 underwaterVector = viewSpacePosition.xyz - viewSpacePosition1.xyz;
	
	float UdotN = abs(dot(normalize(underwaterVector.xyz), normal));
	
	float depth = length(underwaterVector.xyz) * UdotN;
	      depth = exp(-depth * 0.35);
	
	float fogFactor = CalculateFogFactor(viewSpacePosition1.xyz, 10.0);
	
	return 1.0 - clamp(depth - fogFactor, 0.0, 1.0);
}

void AddUnderwaterFog(inout vec3 color, in vec4 viewSpacePosition, in vec4 viewSpacePosition1, in vec3 normal, in Mask mask) {
	vec3 waterVolumeColor = vec3(0.0, 0.01, 0.1) * colorSkylight;
	
	if (mask.water > 0.5)
		color = mix(color, waterVolumeColor, ComputeSkyAbsorbance(viewSpacePosition, viewSpacePosition1, normal));
}


void main() {
	Mask mask;
	CalculateMasks(mask, GetMaterialID(texcoord), true);
	
	vec3  diffuse           = (mask.sky < 0.5 ?            GetDiffuse(texcoord) : vec3(0.0));    // These ternary statements avoid redundant texture lookups for sky pixels
	vec3  normal            = (mask.sky < 0.5 ?             GetNormal(texcoord) : vec3(0.0));
	float depth             = (mask.sky < 0.5 ?              GetDepth(texcoord) : 1.0);
	float depth1            = (mask.sky < 0.5 ?   GetTransparentDepth(texcoord) : 1.0);    // Going to append a "1" onto the end of anything that represents first-layer transparency
	
	vec4  viewSpacePosition  = CalculateViewSpacePosition(texcoord,  depth);
	vec4  viewSpacePosition1 = CalculateViewSpacePosition(texcoord, depth1);
	
	if (mask.sky > 0.5) { gl_FragData[0] = vec4(EncodeColor(CalculateSky(viewSpacePosition.xyz)), 1.0); return; }    // I would discard the sky here and do sky color in the next shader stage, except that reflections tend to catch sky pixels around the edges of reflected blocks
	
	#ifdef DEFERRED_SHADING
	float torchLightmap     = GetTorchLightmap(texcoord);
	float skyLightmap       = GetSkyLightmap(texcoord);
	
	vec3 composite = CalculateShadedFragment(diffuse, mask, torchLightmap, skyLightmap, normal, viewSpacePosition);
	#else
	vec3 composite = DecodeColor(texture2D(colortex2, texcoord).rgb);
	#endif
	
	
	vec3 GI; float Fog;
	BilateralUpsample(normal, depth, mask, GI, Fog);
	
	composite += GI * colorSunlight * pow(diffuse, vec3(2.2));
	
	
	AddUnderwaterFog(composite, viewSpacePosition, viewSpacePosition1, normal, mask);
	
	gl_FragData[0] = vec4(EncodeColor(composite), 1.0);
	gl_FragData[1] = vec4(EncodeColor(GI), Fog);
}