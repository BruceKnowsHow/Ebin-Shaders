#version 410 compatibility
#define composite2
#define fsh
#define ShaderStage 2
#include "/lib/Syntax.glsl"

/* DRAWBUFFERS:3 */

const bool colortex1MipmapEnabled = true;

uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D gdepthtex;
uniform sampler2D depthtex1;
uniform sampler2D noisetex;
uniform sampler2DShadow shadow; 

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
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
varying vec2 pixelSize;

#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"
#include "/lib/Debug.glsl"
#include "/lib/Uniform/Global_Composite_Variables.glsl"
#include "/lib/Fragment/Masks.fsh"
#include "/lib/Misc/Calculate_Fogfactor.glsl"


vec3 GetColor(vec2 coord) {
	return texture2D(colortex1, coord).rgb;
}

vec3 GetColorLod(vec2 coord, float lod) {
	return texture2DLod(colortex1, coord, lod).rgb;
}

float GetDepth(vec2 coord) {
	return texture2D(gdepthtex, coord).x;
}

float GetTransparentDepth(vec2 coord) {
	return texture2D(depthtex1, coord).x;
}

vec4 CalculateViewSpacePosition(vec2 coord, float depth) {
	vec4 position  = gbufferProjectionInverse * vec4(vec3(coord, depth) * 2.0 - 1.0, 1.0);
	     position /= position.w;
	
	return position;
}

vec3 ViewSpaceToScreenSpace(vec4 viewSpacePosition) {
	vec4 screenSpace = gbufferProjection * viewSpacePosition;
	
	return (screenSpace.xyz / screenSpace.w) * 0.5 + 0.5;
}


#include "/lib/Fragment/Water_Waves.fsh"
#include "/lib/Fragment/Sky.fsh"

bool ComputeRaytracedIntersection(vec3 startingViewPosition, vec3 rayDirection, float firstStepSize, cfloat rayGrowth, cint maxSteps, cint maxRefinements, out vec3 screenSpacePosition, out vec4 viewSpacePosition) {
	vec3 rayStep = rayDirection * firstStepSize;
	vec4 ray = vec4(startingViewPosition + rayStep, 1.0);
	
	screenSpacePosition = ViewSpaceToScreenSpace(ray);
	
	float refinements = 0.0;
	float refinementCoeff = 1.0;
	
	cbool doRefinements = (maxRefinements > 0);
	
	float maxRayDepth = -far * 1.875;
	
	for (int i = 0; i < maxSteps; i++) {
		if (any(greaterThan(abs(screenSpacePosition.xyz - 0.5), vec3(0.5))) || ray.z < maxRayDepth)
			return false;
		
		float sampleDepth = GetTransparentDepth(screenSpacePosition.st);
		
		viewSpacePosition = CalculateViewSpacePosition(screenSpacePosition.st, sampleDepth);
		
		float diff = viewSpacePosition.z - ray.z;
		
		if (diff >= 0.0) {
			if (doRefinements) {
				float error = firstStepSize * pow(rayGrowth, i) * refinementCoeff;
				
				if(diff <= error * 2.0 && refinements <= maxRefinements) {
					ray.xyz -= rayStep * refinementCoeff;
					refinements += 1.0;
					refinementCoeff = exp2(-refinements);
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

#include "/lib/Misc/Bias_Functions.glsl"
#include "/lib/Fragment/Sunlight/ComputeUniformlySoftShadows.fsh"
#include "/lib/Fragment/Reflectance_Models.fsh"

void ComputeReflectedLight(inout vec3 color, vec4 viewSpacePosition, vec3 normal, float smoothness, float skyLightmap, Mask mask) {
	if (isEyeInWater == 1) return;
	
	vec3  rayDirection  = normalize(reflect(viewSpacePosition.xyz, normal));
	float firstStepSize = mix(1.0, 30.0, pow2(length((gbufferModelViewInverse * viewSpacePosition).xz) / 144.0));
	vec3  reflectedCoord;
	vec4  reflectedViewSpacePosition;
	vec3  reflection;
	
	float roughness = 1.0 - smoothness;
	
	vec3 viewVector = -normalize(viewSpacePosition.xyz);
	vec3 halfVector = normalize(lightVector - viewVector);
	
	float vdotn   = clamp01(dot(viewVector, normal));
	float vdoth   = clamp01(dot(viewVector, halfVector));
	
	cfloat F0 = 0.15; //To be replaced with metalloic
	
	float lightFresnel = Fresnel(F0, vdoth);
	
	vec3 alpha = vec3(lightFresnel * smoothness) * 0.25;
	
	if (length(alpha) < 0.005) return;
	
	
	float sunlight = ComputeShadows(viewSpacePosition, 1.0);
	
	vec3 reflectedSky  = CalculateSky(vec4(reflect(viewSpacePosition.xyz, normal), 1.0), 1.0, true).rgb;
	     reflectedSky *= 1.0;
	
	float reflectedSunspot = specularBRDF(lightVector, normal, F0, -normalize(viewSpacePosition.xyz), roughness) * sunlight;
	
	vec3 offscreen = reflectedSky + reflectedSunspot * sunlightColor * 10.0;
	
	if (!ComputeRaytracedIntersection(viewSpacePosition.xyz, rayDirection, firstStepSize, 1.55, 30, 1, reflectedCoord, reflectedViewSpacePosition))
		reflection = offscreen;
	else {
		reflection = GetColor(reflectedCoord.st);
		
		reflection = mix(reflection, reflectedSky, CalculateFogFactor(reflectedViewSpacePosition, FOG_POWER));
		
		#ifdef REFLECTION_EDGE_FALLOFF
			float angleCoeff = clamp(pow(dot(vec3(0.0, 0.0, 1.0), normal) + 0.15, 0.25) * 2.0, 0.0, 1.0) * 0.2 + 0.8;
			float dist       = length8(abs(reflectedCoord.xy - vec2(0.5)));
			float edge       = clamp(1.0 - pow2(dist * 2.0 * angleCoeff), 0.0, 1.0);
			reflection       = mix(reflection, reflectedSky, pow(1.0 - edge, 10.0));
		#endif
	}
	
	reflection = max(reflection, 0.0);
	
	color = mix(color, reflection, alpha);
}

vec2 GetRefractedCoord(vec2 coord, vec4 viewSpacePosition, vec3 tangentNormal) {
	vec4 screenSpacePosition = gbufferProjection * viewSpacePosition;
	
	float fov = atan(1.0 / gbufferProjection[1].y) * 2.0 / RAD;
	
	cfloat refractAmount = 0.5;
	
	vec2 refraction = tangentNormal.st / fov * 90.0 * refractAmount;
	
	vec2 refractedCoord = screenSpacePosition.st + refraction;
	
	refractedCoord = refractedCoord / screenSpacePosition.w * 0.5 + 0.5;
	
	refractedCoord = clampScreen(refractedCoord, pixelSize);
	
	return refractedCoord;
}

mat3 DecodeTBN(float tbnIndex) {
	tbnIndex = round(tbnIndex * 16.0);
	
	vec3 tangent;
	vec3 binormal;
	
	if (tbnIndex == 1.0) {
		tangent  = vec3( 0.0,  0.0,  1.0);
		binormal = vec3( 0.0, -1.0,  0.0);
	} else if (tbnIndex == 2.0) {
		tangent  = vec3( 0.0,  0.0,  1.0);
		binormal = vec3( 0.0,  1.0,  0.0);
	} else if (tbnIndex == 3.0) {
		tangent  = vec3( 1.0,  0.0,  0.0);
		binormal = vec3( 0.0,  1.0,  0.0);
	} else if (tbnIndex == 4.0) {
		tangent  = vec3( 1.0,  0.0,  0.0);
		binormal = vec3( 0.0, -1.0,  0.0);
	} else if (tbnIndex == 5.0) {
		tangent  = vec3(-1.0,  0.0,  0.0);
		binormal = vec3( 0.0,  0.0, -1.0);
	} else {
		tangent  = vec3( 1.0,  0.0,  0.0);
		binormal = vec3( 0.0,  0.0, -1.0);
	}
	
	vec3 normal = cross(tangent, binormal);
	
	return mat3(tangent, binormal, normal);
}

#include "lib/Fragment/WaterDepthFog.fsh"

void main() {
	float depth0 = GetDepth(texcoord);
	vec4  viewSpacePosition0 = CalculateViewSpacePosition(texcoord, depth0);
	
	
	vec2 encode = Decode16(texture2D(colortex5, texcoord).r);
	float torchLightmap = encode.r;
	Mask mask = CalculateMasks(encode.g);
	
	vec2  refractedCoord     = texcoord;
	float depth1             = depth0;
	vec4  viewSpacePosition1 = viewSpacePosition0;
	vec2  encodedNormal      = vec2(0.0);
	vec3  normal             = vec3(0.0);
	float alpha              = 0.0;
	
	if (depth0 < 1.0) {
		encodedNormal = texture2D(colortex4, texcoord).xy;
		
		if (mask.transparent > 0.5) {
			mat3 tbnMatrix = DecodeTBN(encodedNormal.x);
			
			vec3 tangentNormal;
			
			if (mask.water > 0.5) tangentNormal.xy = GetWaveNormals(viewSpacePosition0, tbnMatrix[2]);
			else                  tangentNormal.xy = Decode16(encodedNormal.y) * 2.0 - 1.0;
			
			tangentNormal.z = sqrt(1.0 - lengthSquared(tangentNormal.xy)); // Solve the equation "length(normal.xyz) = 1.0" for normal.z
			
			normal = normalize((gbufferModelView * vec4(tbnMatrix * tangentNormal, 0.0)).xyz);
			
			
			refractedCoord = GetRefractedCoord(texcoord, viewSpacePosition0, tangentNormal);
			
			depth1 = (mask.hand > 0.5 ? depth0 : GetTransparentDepth(refractedCoord));
			viewSpacePosition1 = CalculateViewSpacePosition(refractedCoord, depth1);
			
			alpha = texture2D(colortex2, refractedCoord).r;
		}
	}
	
	vec3 sky = CalculateSky(viewSpacePosition1, 1.0 - alpha, false);
	
	if (isEyeInWater == 1) sky = waterFog(sky, viewSpacePosition0, vec4(0.0));
	
	if (depth0 >= 1.0) { gl_FragData[0] = vec4(EncodeColor(sky.rgb), 1.0); exit(); return; }
	
	
	float smoothness;
	float skyLightmap;
	Decode16(texture2D(colortex4, texcoord).b, smoothness, skyLightmap);
	smoothness = mix(smoothness, 0.90, mask.water);
	
	vec3 color0 = vec3(0.0);
	vec3 color1 = vec3(0.0);
	
	if (mask.transparent > 0.5) {
		color0 = texture2D(colortex3, refractedCoord).rgb / alpha;
		
		if (any(isnan(color0))) color0 = vec3(0.0);
	} else {
		normal = DecodeNormal(encodedNormal.xy);
	}
	
	color1 = texture2D(colortex1, refractedCoord).rgb;
	
	color0 = mix(color1, color0, mask.transparent - mask.water);
	
	
	ComputeReflectedLight(color0, viewSpacePosition0, normal, smoothness, skyLightmap, mask);
	
	
	if (depth1 >= 1.0)
		color0 = mix(sky.rgb, color0, mix(alpha, 0.0, isEyeInWater == 1));
	
	
	color0 = mix(color0, sky.rgb, CalculateFogFactor(viewSpacePosition0, FOG_POWER));
	color1 = mix(color1, sky.rgb, CalculateFogFactor(viewSpacePosition1, FOG_POWER));
	
	if (depth1 < 1.0 && mask.transparent > 0.5) color0 = mix(color1, color0, alpha);
	
	
	gl_FragData[0] = vec4(EncodeColor(color0), 1.0);
	
	exit();
}
