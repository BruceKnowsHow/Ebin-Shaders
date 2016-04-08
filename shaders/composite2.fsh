#version 120

/* DRAWBUFFERS:0 */

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D gdepthtex;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelViewInverse;

uniform vec3 cameraPosition;

uniform float near;
uniform float far;

varying vec2 texcoord;

#include "/lib/Settings.glsl"
#include "/lib/Util.glsl"
#include "/lib/GlobalCompositeVariables.fsh"
#include "/lib/Masks.glsl"
#include "/lib/CalculateFogFactor.glsl"


vec3 DecodeColor(in vec3 color) {
	return pow(color, vec3(2.2)) * 1000.0;
}

vec3 EncodeColor(in vec3 color) {    // Prepares the color to be sent through a limited dynamic range pipeline
	return pow(color * 0.001, vec3(1.0 / 2.2));
}

vec3 GetColor(in vec2 coord) {
	return DecodeColor(texture2D(colortex2, coord).rgb);
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

vec3 CalculateAtmosphereScattering(in vec4 viewSpacePosition) {
	float factor  = pow(length(viewSpacePosition.xyz), 1.4) * 0.0002;
	
	return pow(colorSkylight, vec3(3.5)) * factor;
}

vec3 CalculateSky(in vec4 viewSpacePosition, in float fogVolume, in Mask mask) {
	float fogFactor  = 1.0;
	vec3  gradient   = CalculateSkyGradient(viewSpacePosition);
	vec3  sunspot    = CalculateSunspot(viewSpacePosition) * pow(fogFactor, 25);
	vec3  atmosphere = CalculateAtmosphereScattering(viewSpacePosition);
	vec4  skyComposite;
	
	
	skyComposite.a   = GetSkyAlpha(fogVolume, fogFactor);
	skyComposite.rgb = gradient + sunspot;
	
	return skyComposite.rgb + atmosphere;
}

vec3 ViewSpaceToScreenSpace(vec3 viewSpacePosition) {
    vec4 screenSpace = gbufferProjection * vec4(viewSpacePosition, 1.0);
    
    return (screenSpace.xyz / screenSpace.w) * 0.5 + 0.5;
}

bool ComputeRaytracedIntersection(in vec3 startingViewPosition, in vec3 rayDirection, in float firstStepSize, const in float rayGrowth, const in int maxSteps, const in int maxRefinements, out vec3 screenSpacePosition) {
	vec3 rayStep = rayDirection * firstStepSize;
	vec3 ray = startingViewPosition + rayStep;
	
	screenSpacePosition = ViewSpaceToScreenSpace(ray);
	
	float refinements = 0;
	float refinementCoeff = 1.0;
	
	const bool doRefinements = (maxRefinements > 0);
	
	for (int i = 0; i < maxSteps; i++) {
		if (screenSpacePosition.x < 0.0 || screenSpacePosition.x > 1.0 ||
			screenSpacePosition.y < 0.0 || screenSpacePosition.y > 1.0 ||
			screenSpacePosition.z < 0.0 || screenSpacePosition.z > 1.0 ||
			-ray.z < near               || -ray.z > far * 1.6 + 16.0)
		{   return false; }
		
		float sampleDepth        = GetDepth(screenSpacePosition.st);
		vec4  sampleViewPosition = CalculateViewSpacePosition(screenSpacePosition.st, sampleDepth);
		
		float diff = sampleViewPosition.z - ray.z;
		
		if (diff >= 0) {
			if (doRefinements) {
				float error = length(rayStep) * refinementCoeff;
				
				if(diff <= error * 2.0 && refinements <= maxRefinements) {
					ray -= rayStep * refinementCoeff;
					refinementCoeff = 1.0 / exp2(++refinements);
				} else if (diff <= error * 4.0 && refinements > maxRefinements) {
					screenSpacePosition.z = sampleDepth;
					return true;
				}
			}
			else
				return true;
		}
		
		ray += rayStep * refinementCoeff;
		
		rayStep *= rayGrowth;
		
		screenSpacePosition = ViewSpaceToScreenSpace(ray);
	}
	
	return false;
}

vec3 ComputeRaytracedReflection(in vec4 viewSpacePosition, in vec3 normal, in Mask mask) {
	vec3 reflectedCoord;
	
	float firstStepSize = mix(1.0, 30.0, pow2(length((gbufferModelViewInverse * viewSpacePosition).xz) / 144.0));
	
	if (ComputeRaytracedIntersection(viewSpacePosition.xyz, normalize(reflect(viewSpacePosition.xyz, normal)), firstStepSize, 1.3, 30, 3, reflectedCoord))
	return GetColor(reflectedCoord.st);
	else return CalculateSky(vec4(reflect(viewSpacePosition.xyz, normal), 1.0), 1.0, mask);
}


void main() {
	Mask mask;
	CalculateMasks(mask, texture2D(colortex3, texcoord).b, true);
	
	vec3  color             = (GetColor(texcoord));    // These ternary statements avoid redundant texture lookups for sky pixels.
	vec3  normal            = (mask.sky < 0.5 ? GetNormal(texcoord) : vec3(0.0));
	float depth             = (mask.sky < 0.5 ?  GetDepth(texcoord) : 1.0);
	
	vec4  viewSpacePosition = CalculateViewSpacePosition(texcoord,  depth);
	
	if (mask.water > 0.5)
	color = ComputeRaytracedReflection(viewSpacePosition, normal, mask);
	
	gl_FragData[0] = vec4(EncodeColor(color), 1.0);
}