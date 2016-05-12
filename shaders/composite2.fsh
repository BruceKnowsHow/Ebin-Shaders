#version 120
#define composite2_fsh true
#define ShaderStage 2

/* DRAWBUFFERS:0 */

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D gdepthtex;
uniform sampler2D noisetex;

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
#include "/lib/DebugSetup.glsl"
#include "/lib/GlobalCompositeVariables.fsh"
#include "/lib/Masks.glsl"
#include "/lib/CalculateFogFactor.glsl"


// Reflection stuff
#define OFF 0
#define ON 1

#define MAX_RAY_LENGTH          100.0
#define MAX_DEPTH_DIFFERENCE    1.5 // How much of a step between the hit pixel and anything else is allowed?
#define RAY_STEP_LENGTH         0.05
#define RAY_DEPTH_BIAS          0.05 // Serves the same purpose as a shadow bias
#define RAY_GROWTH              1.15  // Make this number smaller to get more accurate reflections at the cost of performance
                                      // numbers less than 1 are not recommended as they will cause ray steps to grow
                                      // shorter and shorter until you're barely making any progress
#define NUM_RAYS                2   // The best setting in the whole shader pack. If you increase this value,
                                    // more and more rays will be sent per pixel, resulting in better and better
                                    // reflections. If you computer can handle 4 (or even 16!) I highly recommend it.

#define DITHER_REFLECTION_RAYS OFF


vec3 GetColor(in vec2 coord) {
	return DecodeColor(texture2D(colortex2, coord).rgb);
}

float GetDepth(in vec2 coord) {
	return texture2D(gdepthtex, coord).x;
}

float GetSmoothness(in vec2 coord) {
	return pow(texture2D(colortex0, texcoord).b, 2.2);
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
	return DecodeNormal(texture2D(colortex0, coord).xy);
}

float GetVolumetricFog(in vec2 coord) {
	return texture2D(colortex4, coord).a;
}

float calculateDitherPattern() {
  const int[64] ditherPattern = int[64] ( 1, 49, 13, 61,  4, 52, 16, 64,
                                         33, 17, 45, 29, 36, 20, 48, 32,
                                          9, 57,  5, 53, 12, 60,  8, 56,
                                         41, 25, 37, 21, 44, 28, 40, 24,
                                          3, 51, 15, 63,  2, 50, 14, 62,
                                         35, 19, 47, 31, 34, 18, 46, 30,
                                         11, 59,  7, 55, 10, 58,  6, 54,
                                         43, 27, 39, 23, 42, 26, 38, 22);

  vec2 count;
	   count.x = floor(mod(texcoord.s * viewWidth , 8.0));
	   count.y = floor(mod(texcoord.t * viewHeight, 8.0));
	
	int dither = ditherPattern[int(count.x) + int(count.y) * 8];

	return float(dither) / 64.0;
}

#include "/lib/Sky.fsh"

bool ComputeRaytracedIntersection(in vec3 startingViewPosition, in vec3 rayDirection, in float firstStepSize, const float rayGrowth, const int maxSteps, const int maxRefinements, out vec3 screenSpacePosition, out vec4 viewSpacePosition) {
	vec3 rayStep = rayDirection * firstStepSize;
	vec4 ray = vec4(startingViewPosition + rayStep, 1.0);
	
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
			else
				return true;
		}
		
		ray.xyz += rayStep * refinementCoeff;
		
		rayStep *= rayGrowth;
		
		screenSpacePosition = ViewSpaceToScreenSpace(ray);
	}
	
	return false;
}

void ComputeRaytracedReflection(inout vec3 color, in vec4 viewSpacePosition, in vec3 normal, in Mask mask) {
	vec3  rayDirection  = normalize(reflect(viewSpacePosition.xyz, normal));
	float firstStepSize = mix(1.0, 30.0, pow2(length((gbufferModelViewInverse * viewSpacePosition).xz) / 144.0));
	vec3  reflectedCoord;
	vec4  reflectedViewSpacePosition;
	vec3  reflection;
	
	vec3 reflectedSky = CalculateSky(vec4(reflect(viewSpacePosition.xyz, normal), 1.0));
	
	if (!ComputeRaytracedIntersection(viewSpacePosition.xyz, rayDirection, firstStepSize, 1.3, 30, 3, reflectedCoord, reflectedViewSpacePosition))
		reflection = reflectedSky;
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
	
	float VdotN = dot(normalize(viewSpacePosition.xyz), normal);
	float alpha = pow(min(1.0 + VdotN, 1.0), 9.0) * 0.99 + 0.01;
	
	color = mix(color, reflection, alpha);
}

vec3 pbrScreenSpaceRay(in vec3 origin, in vec3 direction, in float depth) {
	vec3 curPos = origin;
	vec2 curCoord = ViewSpaceToScreenSpace(curPos).xy;
	direction = normalize(direction) * RAY_STEP_LENGTH;
	
#if DITHER_REFLECTION_RAYS == ON
	direction *= calculateDitherPattern();
#endif
	
	bool forward = true;
	bool can_collect = true;
	
	for(int i = 0; i < MAX_RAY_LENGTH / RAY_STEP_LENGTH; i++) {
		curPos += direction;
		curCoord = ViewSpaceToScreenSpace(curPos).xy;
		
		if (curCoord.x < 0.0 || curCoord.x > 1.0 ||
		    curCoord.y < 0.0 || curCoord.y > 1.0) {
			return vec3(-1.0); // If we're here, the ray has gone off-screen so we can't reflect anything
		}
		
		if (length(curPos - origin) > MAX_RAY_LENGTH) return vec3(-1.0);
		
		float depth        = texture2D(gdepthtex, curCoord).x;
		float worldDepth   = CalculateViewSpacePosition(curCoord, depth).z;
		float rayDepth     = curPos.z;
		float depthDiff    = (worldDepth - rayDepth);
		float maxDepthDiff = length(direction) + RAY_DEPTH_BIAS;
		
		if (depthDiff > 0.0 && depthDiff < maxDepthDiff) {
			vec3 travelled = origin - curPos;
			
			return vec3(curCoord, length(travelled));
			
			// We just returned, these lines are irrelevant right? FIXME
		//	direction = -1.0 * normalize(direction) * 0.15;
		//	forward = false;
		}
		
		direction *= RAY_GROWTH;
	}
	return vec3(-1);
}

vec3 pbrBounce(in vec4 viewSpacePosition, in vec3 normal, in float smoothness, in float depth) {
	int hitLayer = 0;
	vec2 noiseCoord = vec2(texcoord.s * viewWidth / 64.0, texcoord.t * viewHeight / 64.0);
	vec3 rayStart = viewSpacePosition.xyz;
	vec3 retColor = vec3(0);
	vec3 noiseSample = vec3(0);
	vec3 reflectDir = vec3(0);
	vec3 rayDir = vec3(0);
	vec3 hitUV = vec3(0);
	vec3 hitColor = vec3(0);
	
	//trace the number of rays defined previously
	for(int i = 0; i < NUM_RAYS; i++) {
		noiseSample = texture2DLod(noisetex, noiseCoord * (i + 1), 0).rgb * 2 - 1;
		reflectDir  = normalize(noiseSample * (1.0 - smoothness) * 0.5 + normal);
		reflectDir *= sign(dot(normal, reflectDir));
		rayDir      = reflect(normalize(rayStart), reflectDir);
		
		if (dot(rayDir, normal) < 0.1)
			rayDir = normalize(rayDir + normal);
			
			hitUV = pbrScreenSpaceRay(rayStart, rayDir, depth);
			
			if (hitUV.z < RAY_STEP_LENGTH * 2.0)
					hitUV.s = 100; // If the ray is pointing into the object, just sample the sky and be done with it
			
			if (hitUV.s > -0.1 && hitUV.s < 1.1 && hitUV.t > -0.1 && hitUV.t < 1.1) {
				vec3 reflection_sample = DecodeColor(texture2DLod(colortex2, hitUV.st, 0).rgb);
				
				retColor += reflection_sample;
			} else {
				vec3 reflected_sky_color = CalculateSky(vec4(reflect(viewSpacePosition.xyz, normal), 1.0)) * 0.1;
				retColor += reflected_sky_color;
			}
	}
	
	return retColor / NUM_RAYS;
}

void main() {
	Mask mask;
	CalculateMasks(mask, texture2D(colortex3, texcoord).b);
	
	vec3 color = GetColor(texcoord);
	
	if (mask.sky > 0.5) { gl_FragData[0] = vec4(EncodeColor(color), 1.0); exit(); return;}
	
	vec3  normal = (mask.sky < 0.5 ? GetNormal(texcoord) : vec3(0.0)); // These ternary statements avoid redundant texture lookups for sky pixels
	float depth  = (mask.sky < 0.5 ?  GetDepth(texcoord) : 1.0);       // Sky was calculated in the last file, otherwise color would be included in these ternary conditions
	float smoothness = GetSmoothness(texcoord);
	
	vec4 viewSpacePosition = CalculateViewSpacePosition(texcoord,  depth);
	
	
	if (mask.water > 0.5)
		ComputeRaytracedReflection(color, viewSpacePosition, normal, mask);
	
	if (mask.water < 0.5) {
		float vdoth = clamp(dot(-normalize(viewSpacePosition.xyz), normal), 0, 1);
		vec3 sColor = mix(vec3(0.14), color, vec3(0.0));
		vec3 fresnel = sColor + (vec3(1.0) - sColor) * pow(1.0 - vdoth, 5);
		
		vec3 bounce = pbrBounce(viewSpacePosition, normal, smoothness, depth);
		color = mix(color, bounce, fresnel * smoothness);
	}
	
	
	CompositeFog(color, viewSpacePosition, GetVolumetricFog(texcoord));
	
	
	gl_FragData[0] = vec4(EncodeColor(color), 1.0);
	
	exit();
}
