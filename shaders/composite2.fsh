#version 410 compatibility
#define composite2
#define fsh
#define ShaderStage 2
#include "/lib/Syntax.glsl"


/* DRAWBUFFERS:1 */

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D gdepthtex;
uniform sampler2D depthtex1;
uniform sampler2D noisetex;
uniform sampler2DShadow shadow; 

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform vec3 cameraPosition;

uniform float frameTimeCounter;
uniform float rainStrength;

uniform float viewWidth;
uniform float viewHeight;

uniform float near;
uniform float far;

uniform int isEyeInWater;

varying vec2 texcoord;

#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"
#include "/lib/DebugSetup.glsl"
#include "/lib/Uniform/GlobalCompositeVariables.glsl"
#include "/lib/Fragment/Masks.fsh"
#include "/lib/Misc/CalculateFogFactor.glsl"
#include "/lib/Fragment/ReflectanceModel.fsh"

const bool colortex2MipmapEnabled = true;


vec3 GetColor(in vec2 coord) {
	return DecodeColor(texture2D(colortex2, coord).rgb);
}

vec3 GetColorLod(in vec2 coord, in float lod) {
	return DecodeColor(texture2DLod(colortex2, coord, lod).rgb);
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

vec3 ViewSpaceToScreenSpace(vec3 viewSpacePosition) {
	vec4 screenSpace = gbufferProjection * vec4(viewSpacePosition, 1.0);
	
	return (screenSpace.xyz / screenSpace.w) * 0.5 + 0.5;
}

vec3 ViewSpaceToScreenSpace(vec4 viewSpacePosition) {
	vec4 screenSpace = gbufferProjection * viewSpacePosition;
	
	return (screenSpace.xyz / screenSpace.w) * 0.5 + 0.5;
}

vec3 GetNormal(in vec2 coord) {
	return DecodeNormal(texture2D(colortex1, coord).xy);
}

#include "/lib/Fragment/WaterWaves.fsh"

float GetVolumetricFog(in vec2 coord) {
	return texture2D(colortex4, coord).a;
}

float noise(in vec2 coord) {
    return fract(sin(dot(coord, vec2(12.9898, 4.1414))) * 43758.5453);
}


#include "/lib/Fragment/CalculateShadedFragment.fsh"

#include "/lib/Fragment/Sky.fsh"

bool ComputeRaytracedIntersection(in vec3 startingViewPosition, in vec3 rayDirection, in float firstStepSize, cfloat rayGrowth, cint maxSteps, cint maxRefinements, out vec3 screenSpacePosition, out vec4 viewSpacePosition) {
	vec3 rayStep = rayDirection * firstStepSize;
	vec4 ray = vec4(startingViewPosition + rayStep, 1.0);
	
	screenSpacePosition = ViewSpaceToScreenSpace(ray);
	
	float refinements = 0;
	float refinementCoeff = 1.0;
	
	cbool doRefinements = (maxRefinements > 0);
	
	float maxRayDepth = -(far * 1.6 + 16.0);
	
	for (int i = 0; i < maxSteps; i++) {
		if (any(greaterThan(abs(screenSpacePosition.xyz - 0.5), vec3(0.5))) || ray.z < maxRayDepth)
			return false;
		
		float sampleDepth = GetDepth(screenSpacePosition.st);
		
		viewSpacePosition = CalculateViewSpacePosition(screenSpacePosition.st, sampleDepth);
		
		float diff = viewSpacePosition.z - ray.z;
		
		if (diff >= 0) {
			if (doRefinements) {
				float error = firstStepSize * pow(rayGrowth, i) * refinementCoeff;
				
				if(diff <= error * 2.0 && refinements <= maxRefinements) {
					ray.xyz -= rayStep * refinementCoeff;
					refinementCoeff = 1.0 / exp2(++refinements);
				} else if (diff <= error * 4.0 && refinements > maxRefinements) {
					screenSpacePosition.z = sampleDepth;
					return true;
				}
			}
			
			else return true;
		}
		
		ray.xyz += rayStep * refinementCoeff;
		
		rayStep *= rayGrowth;
		
		screenSpacePosition = ViewSpaceToScreenSpace(ray);
	}
	
	return false;
}

#ifndef PBR
void ComputeReflectedLight(inout vec3 color, in vec4 viewSpacePosition, in vec3 normal, in float smoothness, in float skyLightmap, in Mask mask) {
	if (mask.water < 0.5) smoothness = pow(smoothness, 4.8);
	
	vec3  rayDirection  = normalize(reflect(viewSpacePosition.xyz, normal));
	float firstStepSize = mix(1.0, 30.0, pow2(length((gbufferModelViewInverse * viewSpacePosition).xz) / 144.0));
	vec3  reflectedCoord;
	vec4  reflectedViewSpacePosition;
	vec3  reflection;
	
	float roughness = 1.0 - smoothness;
	
	float vdoth   = clamp01(dot(-normalize(viewSpacePosition.xyz), normal));
	vec3  sColor  = mix(vec3(0.15), color * 0.2, vec3(mask.metallic));
	vec3  fresnel = Fresnel(sColor, vdoth);
	
	vec3 alpha = fresnel * smoothness;
	
	if (length(alpha) < 0.01) return;
	
	
	float sunlight = ComputeShadows(viewSpacePosition, 1.0);
	
	vec3 reflectedSky  = CalculateSky(vec4(reflect(viewSpacePosition.xyz, normal), 1.0), false);
	     reflectedSky *= 1.0;
	
	vec3 reflectedSunspot = CalculateSpecularHighlight(lightVector, normal, fresnel, -normalize(viewSpacePosition.xyz), roughness) * sunlight;
	
	vec3 offscreen = reflectedSky + reflectedSunspot * sunlightColor * 100.0;
	
	if (!ComputeRaytracedIntersection(viewSpacePosition.xyz, rayDirection, firstStepSize, 1.3, 30, 3, reflectedCoord, reflectedViewSpacePosition))
		reflection = offscreen;
	else {
		reflection = GetColor(reflectedCoord.st);
		
		vec3 reflectionVector = normalize(reflectedViewSpacePosition.xyz - viewSpacePosition.xyz) * length(reflectedViewSpacePosition.xyz); // This is not based on any physical property, it just looked around when I was toying around
		
		CompositeFog(reflection, vec4(reflectionVector, 1.0), GetVolumetricFog(reflectedCoord.st));
		
		#ifdef REFLECTION_EDGE_FALLOFF
			float angleCoeff = clamp(pow(dot(vec3(0.0, 0.0, 1.0), normal) + 0.15, 0.25) * 2.0, 0.0, 1.0) * 0.2 + 0.8;
			float dist       = length8(abs(reflectedCoord.xy - vec2(0.5)));
			float edge       = clamp(1.0 - pow2(dist * 2.0 * angleCoeff), 0.0, 1.0);
			reflection       = mix(reflection, reflectedSky, pow(1.0 - edge, 10.0));
		#endif
	}
	
	color = mix(color, reflection, fresnel * smoothness);
}

#else
void ComputeReflectedLight(inout vec3 color, in vec4 viewSpacePosition, in vec3 normal, in float smoothness, in float skyLightmap, in Mask mask) {
	if (mask.water < 0.5) smoothness = pow(smoothness, 4.8);
	
	float firstStepSize = mix(1.0, 30.0, pow2(length((gbufferModelViewInverse * viewSpacePosition).xz) / 144.0));
	vec3  reflectedCoord;
	vec4  reflectedViewSpacePosition;
	vec3  reflection;
	
	float roughness = 1.0 - smoothness;
	
	#define IOR 0.15 // [0.05 0.1 0.15 0.25 0.5]
	
	float vdoth   = clamp01(dot(-normalize(viewSpacePosition.xyz), normal));
	vec3  sColor  = mix(vec3(IOR), color * 0.2, vec3(mask.metallic));
	vec3  fresnel = Fresnel(sColor, vdoth);
	
	vec3 alpha = fresnel * smoothness;
	
	//This breaks some things.
	//if (length(alpha) < 0.01) return;
	
	float sunlight = ComputeShadows(viewSpacePosition, 1.0);
	
	vec3 reflectedSky  = CalculateSky(vec4(reflect(viewSpacePosition.xyz, normal), 1.0), false);
	vec3 reflectedSunspot = CalculateSpecularHighlight(lightVector, normal, fresnel, -normalize(viewSpacePosition.xyz), roughness) * sunlight;
	
	vec3 offscreen = reflectedSky + reflectedSunspot * sunlightColor * 100.0;
	
	
	for (uint i = 1; i <= PBR_RAYS; i++) {
		vec2 epsilon  = vec2(noise(texcoord * i), noise(texcoord * i * 3));
		vec3 BRDFSkew = skew(epsilon, roughness);
		
		vec3 reflectDir  = normalize(normal + BRDFSkew * roughness / 12.0);
		     reflectDir *= sign(dot(normal, reflectDir));
		
		vec3 rayDirection = reflect(normalize(viewSpacePosition.xyz), reflectDir);
		
		
		if (!ComputeRaytracedIntersection(viewSpacePosition.xyz, rayDirection, firstStepSize, 1.3, 30, 3, reflectedCoord, reflectedViewSpacePosition)) { //this is much faster I tested
			reflection += offscreen + 0.1 * mask.metallic;
		} else {
			vec3 reflectionVector = normalize(reflectedViewSpacePosition.xyz - viewSpacePosition.xyz) * length(reflectedViewSpacePosition.xyz); // This is not based on any physical property, it just looked around when I was toying around
			// Maybe give previous reflection Intersection to make sure we dont compute rays in the same pixel twice.
			
			vec3 colorSample = GetColorLod(reflectedCoord.st, 2);
			
			CompositeFog(colorSample, vec4(reflectionVector, 1.0), GetVolumetricFog(reflectedCoord.st));
			
			#ifdef REFLECTION_EDGE_FALLOFF
				float angleCoeff = clamp(pow(dot(vec3(0.0, 0.0, 1.0), normal) + 0.15, 0.25) * 2.0, 0.0, 1.0) * 0.2 + 0.8;
				float dist       = length8(abs(reflectedCoord.xy - vec2(0.5)));
				float edge       = clamp(1.0 - pow2(dist * 2.0 * angleCoeff), 0.0, 1.0);
				colorSample      = mix(colorSample, reflectedSky, pow(1.0 - edge, 10.0));
			#endif
			
			reflection += colorSample;
		}
	}
	
	reflection /= PBR_RAYS;
	
	color = mix(color * (1.0 - mask.metallic * 0.9), reflection, alpha);
}
#endif

mat3 GetWaterTBN() {
	vec3 normal = DecodeNormal(texture2D(colortex3, texcoord).xy);
	
	vec3 worldNormal = normalize((gbufferModelViewInverse * vec4(normal, 0.0)).xyz);
	
	vec3 y = cross(worldNormal, vec3(0.0, 1.0, 0.0));
	vec3 z = cross(worldNormal, vec3(0.0, 0.0, 1.0));
	
	vec3 tangent = (length(y) > length(z) ? y : z);
	
	tangent = normalize((gbufferModelView * vec4(tangent, 0.0)).xyz);
	
	vec3 binormal = normalize(cross(normal, tangent));
	
	return transpose(mat3(tangent, binormal, normal));
}

void AddWater(in vec4 viewSpacePosition, inout Mask mask, out vec3 color, out vec3 normal, out float smoothness, out vec3 tangentNormal, out mat3 tbnMatrix) {
	mask.metallic = 0.0;
	color         = vec3(0.0, 0.015, 0.2);
	tbnMatrix     = GetWaterTBN();
	tangentNormal = GetWaveNormals(viewSpacePosition, transpose(tbnMatrix)[2]);
	normal        = normalize(tangentNormal * tbnMatrix);
	smoothness    = 0.85;
}

mat3x2 GetRefractedCoordinates(in vec2 coord, in vec4 viewSpacePosition, in vec4 viewSpacePosition1, in vec3 normal, in vec3 tangentSpaceWave) {
	vec4 screenSpacePosition = gbufferProjection * viewSpacePosition;
	
	float fov = atan(1.0 / gbufferProjection[1].y) * 2.0 / RAD;
	
	float VdotN        = dot(-normalize(viewSpacePosition.xyz), normalize(normal));
	float surfaceDepth = sqrt(length(viewSpacePosition1.xyz - viewSpacePosition.xyz)) * VdotN;
	
	cfloat refractAmount = 0.5;
	cfloat aberrationAmount = 1.0 + 0.2;
	
	vec2 refraction = tangentSpaceWave.st / fov * 90.0 * refractAmount * min(surfaceDepth, 1.0);
	
	mat3x2 coords = mat3x2(screenSpacePosition.st + refraction * aberrationAmount,
	                       screenSpacePosition.st + refraction,
	                       screenSpacePosition.st + refraction);
	
	coords = coords / screenSpacePosition.w * 0.5 + 0.5;
	
	vec2 pixelSize = 1.0 / vec2(viewWidth, viewHeight);
	vec2 minCoord  = pixelSize;
	vec2 maxCoord  = 1.0 - pixelSize;
	
	coords[0] = clamp(coords[0], minCoord, maxCoord);
	coords[1] = clamp(coords[1], minCoord, maxCoord);
	coords[2] = clamp(coords[2], minCoord, maxCoord);
	
	return coords;
}

vec3 GetRefractedColor(in vec2 coord, in vec4 viewSpacePosition, in vec4 viewSpacePosition1, in vec3 normal, in vec3 tangentSpaceWave, in float waterMask) {
	mat3x2 coords = ( waterMask > 0.5 ? 
		GetRefractedCoordinates(coord, viewSpacePosition, viewSpacePosition1, normal, tangentSpaceWave) :
		mat3x2(coord.st, coord.st, coord.st) );
	
	
	vec3 color = vec3(texture2D(colortex2, coords[0]).r,
	                  texture2D(colortex2, coords[1]).g,
	                  texture2D(colortex2, coords[2]).b);
	
	return DecodeColor(color);
}

void CompositeWater(inout vec3 color, in vec3 uColor, in float depth1, in float waterMask) {
	if (waterMask < 0.5 || depth1 >= 1.0) return;
	
	color = mix(color, uColor, 0.4);
}


void main() {
	float depth = GetDepth(texcoord);
	vec4 viewSpacePosition = CalculateViewSpacePosition(texcoord, depth);
	
	
	if (depth >= 1.0) { gl_FragData[0] = vec4(EncodeColor(CalculateSky(viewSpacePosition, true)), 1.0); exit(); return; }
	
	
	vec3 encode; float torchLightmap, skyLightmap, smoothness; Mask mask;
	DecodeBuffer(texcoord, colortex0, encode, torchLightmap, skyLightmap, smoothness, mask.materialIDs);
	
	mask = CalculateMasks(mask);
	
	
	vec3 normal = vec3(1.0); float depth1 = 0.0;
	
	if (mask.water + mask.transparent > 0.5) depth1 = GetTransparentDepth(texcoord);
	else normal = GetNormal(texcoord);
	
	
	vec4 viewSpacePosition1 = CalculateViewSpacePosition(texcoord, depth1);
	
	vec3 color = vec3(0.0); vec3 tangentNormal = vec3(0.0); mat3 tbnMatrix;
	if (mask.water > 0.5) AddWater(viewSpacePosition, mask, color, normal, smoothness, tangentNormal, tbnMatrix);
	
	
	vec3 uColor = GetRefractedColor(texcoord, viewSpacePosition, viewSpacePosition1, normal, tangentNormal, mask.water);
	if (mask.water < 0.5) color = uColor; // Save the underwater color until after reflections are applied
	
	ComputeReflectedLight(color, viewSpacePosition, normal, smoothness, skyLightmap, mask);
	
	
	CompositeWater(color, uColor, depth1, mask.water);
	
	
	if (depth1 >= 1.0) color = mix(CalculateSky(viewSpacePosition, true), color, clamp01(mask.water + texture2D(colortex3, texcoord).r));
	
	CompositeFog(color, viewSpacePosition, GetVolumetricFog(texcoord));
	
	
	gl_FragData[0] = vec4(EncodeColor(color), 1.0);
	
	exit();
}
