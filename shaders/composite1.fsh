#version 120

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex6;
uniform sampler2D gdepthtex;
uniform sampler2D shadowcolor;
uniform sampler2DShadow shadow;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelViewInverse;

uniform vec3 cameraPosition;

uniform float viewWidth;
uniform float viewHeight;
uniform float near;
uniform float far;

varying vec2 texcoord;

#include "/lib/Settings.glsl"
#include "/lib/GlobalCompositeVariables.fsh"
#include "/lib/Masks.glsl"
#include "/lib/ShadingFunctions.fsh"
#include "/lib/CalculateFogFactor.glsl"


vec3 DecodeColor(in vec3 color) {
	return pow(color, vec3(2.2)) * 1000.0;
}

vec3 EncodeColor(in vec3 color) {    // Prepares the color to be sent through a limited dynamic range pipeline
	return pow(color * 0.001, vec3(1.0 / 2.2));
}

vec3 GetDiffuse(in vec2 coord) {
	return texture2D((Deferred_Shading ? colortex2 : colortex6), coord).rgb;
}

vec3 GetDiffuseForward(in vec2 coord) {
	return texture2D(colortex6, coord).rgb;
}

vec3 DecodeNormal(vec2 encodedNormal) {
	encodedNormal = encodedNormal * 2.0 - 1.0;
    vec2 fenc = encodedNormal * 4.0 - 2.0;
	float f = dot(fenc, fenc);
	float g = sqrt(1.0 - f / 4.0);
	return vec3(fenc * g, 1.0 - f / 2.0);
}

vec3 GetNormal(in vec2 coord) {
	return DecodeNormal(texture2D(colortex0, coord).xy);
}

float GetDepth(in vec2 coord) {
	return texture2D(gdepthtex, coord).x;
}

float ExpToLinearDepth(in float depth) {
	return 2.0 * near * (far + near - depth * (far - near));
}

vec4 CalculateViewSpacePosition(in vec2 coord, in float depth) {
	vec4 position  = gbufferProjectionInverse * vec4(vec3(coord, depth) * 2.0 - 1.0, 1.0);
	     position /= position.w;
	
	return position;
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

vec3 CalculateSkyGradient(in vec4 viewSpacePosition) {
	float radius = max(176.0, far * sqrt(2.0));
	const float horizonLevel = 72.0;
	
	vec3 worldPosition = (gbufferModelViewInverse * vec4(normalize(viewSpacePosition.xyz), 0.0)).xyz;
	     worldPosition.y = radius * worldPosition.y / length(worldPosition.xz) + cameraPosition.y - horizonLevel;    // Reproject the world vector to have a consistent horizon height
	     worldPosition.xz = normalize(worldPosition.xz) * radius;
	
	float dotUP = dot(normalize(worldPosition), vec3(0.0, 1.0, 0.0));
	
	float horizonCoeff  = dotUP * 0.65;
	      horizonCoeff  = abs(horizonCoeff);
	      horizonCoeff  = pow(1.0 - horizonCoeff, 3.0) / 0.65 * 5.0 + 0.35;
	
	vec3 color = colorSkylight * horizonCoeff;
	
	return color;
}

vec3 CalculateSunspot(in vec4 viewSpacePosition) {
	float sunspot = max(0.0, dot(normalize(viewSpacePosition.xyz), lightVector) - 0.01);
	      sunspot = pow(sunspot, 350.0);
	      sunspot = pow(sunspot + 1.0, 400.0) - 1.0;
	      sunspot = min(sunspot, 20.0);
	      sunspot += 50.0 * float(sunspot == 20.0);
	
	return sunspot * colorSunlight * colorSunlight;
}

void CalculateSky(inout vec3 color, in vec4 viewSpacePosition, in float fogVolume, in Mask mask) {
	float fogFactor = max(CalculateFogFactor(viewSpacePosition, FOG_POWER), mask.sky);
	vec3  gradient  = CalculateSkyGradient(viewSpacePosition);
	vec3  sunspot   = CalculateSunspot(viewSpacePosition) * pow(fogFactor, 25);
	vec4  composite;
	
	
	composite.a   = min(fogVolume * fogFactor + pow(fogFactor, 6) * float(Volumetric_Fog), 1.0);
	composite.rgb = gradient + sunspot;
	
	color = mix(color, composite.rgb, composite.a);
}


void main() {
	Mask mask;
	CalculateMasks(mask, texture2D(colortex3, texcoord).b, true);
	
	vec3  diffuse           = (mask.sky < 0.5 ? GetDiffuse(texcoord) : vec3(0.0));    // These ternary statements avoid redundant texture lookups for sky pixels.
	vec3  normal            = (mask.sky < 0.5 ?  GetNormal(texcoord) : vec3(0.0));
	float depth             = (mask.sky < 0.5 ?   GetDepth(texcoord) : 1.0);
	
	vec4  viewSpacePosition = CalculateViewSpacePosition(texcoord, depth);
	
	#ifdef DEFERRED_SHADING
	float torchLightmap     = texture2D(colortex3, texcoord).r;
	float skyLightmap       = texture2D(colortex3, texcoord).g;
	
	vec3 composite = CalculateShadedFragment(diffuse, mask, torchLightmap, skyLightmap, normal, viewSpacePosition);
	#else
	vec3 composite = DecodeColor(texture2D(colortex2, texcoord).rgb);
	#endif
	
	vec3  GI;
	float Fog;
	
	BilateralUpsample(normal, depth, mask, GI, Fog);
	
	
	composite += GI * colorSunlight * pow(diffuse, vec3(2.2));
	
	CalculateSky(composite, viewSpacePosition, Fog, mask);
	
	gl_FragData[0] = vec4(EncodeColor(composite), 1.0);
}