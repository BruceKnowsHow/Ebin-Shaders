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
uniform sampler2D colortex6;
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

#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"
#include "/lib/Debug.glsl"
#include "/lib/Uniform/Global_Composite_Variables.glsl"
#include "/lib/Fragment/Masks.fsh"
#include "/lib/Misc/Calculate_Fogfactor.glsl"
#include "/lib/Fragment/Reflectance_Models.fsh"


vec3 GetColor(in vec2 coord) {
	return texture2D(colortex1, coord).rgb;
}

vec3 GetColorLod(in vec2 coord, in float lod) {
	return texture2DLod(colortex1, coord, lod).rgb;
}

float GetDepth(in vec2 coord) {
	return texture2D(gdepthtex, coord).x;
}

float GetTransparentDepth(in vec2 coord) {
	return texture2D(depthtex1, coord).x;
}

vec4 CalculateViewSpacePosition(in vec2 coord, in float depth) {
	vec4 position  = gbufferProjectionInverse * vec4(vec3(coord, depth) * 2.0 - 1.0, 1.0);
	     position /= position.w;
	
	return position;
}

vec3 ViewSpaceToScreenSpace(vec4 viewSpacePosition) {
	vec4 screenSpace = gbufferProjection * viewSpacePosition;
	
	return (screenSpace.xyz / screenSpace.w) * 0.5 + 0.5;
}

vec3 GetNormal(in vec2 coord) {
	return DecodeNormal(texture2D(colortex4, coord).xy);
}

float GetVolumetricFog(in vec2 coord) {
#ifdef VOLUMETRIC_FOG
	return texture2D(colortex6, coord).r;
#else
	return 1.0;
#endif
}


#include "/lib/Fragment/Water_Waves.fsh"

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
		
		float sampleDepth = GetTransparentDepth(screenSpacePosition.st);
		
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

#include "/lib/Misc/Bias_Functions.glsl"
#include "/lib/Fragment/Sunlight/ComputeUniformlySoftShadows.fsh"


#include "/lib/Fragment/Reflection_Functions.fsh"


vec2 GetRefractedCoord(in vec2 coord, in vec4 viewSpacePosition, in vec3 tangentNormal) {
	vec4 screenSpacePosition = gbufferProjection * viewSpacePosition;
	
	float fov = atan(1.0 / gbufferProjection[1].y) * 2.0 / RAD;
	
	cfloat refractAmount = 0.5;
	
	vec2 refraction = tangentNormal.st / fov * 90.0 * refractAmount;
	
	vec2 refractedCoord = screenSpacePosition.st + refraction;
	
	refractedCoord = refractedCoord / screenSpacePosition.w * 0.5 + 0.5;
	
	vec2 pixelSize = 1.0 / vec2(viewWidth, viewHeight);
	vec2 minCoord  = pixelSize;
	vec2 maxCoord  = 1.0 - pixelSize;
	
	refractedCoord = clamp(refractedCoord, minCoord, maxCoord);
	
	return refractedCoord;
}

mat3 DecodeTBN(in float tbnIndex) {
	tbnIndex = round(tbnIndex * 16.0);
	
	vec3 tangent;
	vec3 binormal;
	
	if (tbnIndex == 1.0) {
		tangent  = vec3( 0.0,  0.0,  1.0);
		binormal = -tangent.yzy;
	} else if (tbnIndex == 2.0) {
		tangent  = vec3( 0.0,  0.0,  1.0);
		binormal =  tangent.yzy;
	} else if (tbnIndex == 3.0) {
		tangent  = vec3( 1.0,  0.0,  0.0);
		binormal =  tangent.yxy;
	} else if (tbnIndex == 4.0) {
		tangent  = vec3( 1.0,  0.0,  0.0);
		binormal = -tangent.yxy;
	} else if (tbnIndex == 5.0) {
		tangent  = vec3(-1.0,  0.0,  0.0);
		binormal =  tangent.yyx;
	} else {
		tangent  = vec3( 1.0,  0.0,  0.0);
		binormal = -tangent.yyx;
	}
	
	vec3 normal = cross(tangent, binormal);
	
	return mat3(tangent, binormal, normal);
}

vec3 waterFog(in vec3 color1, in vec3 normal, in vec4 viewSpacePosition0, in vec4 viewSpacePosition1, in float skyLightmap) {
	cfloat wrap = 0.2;
	cfloat scatterWidth = 0.5;
	
	float NdotL = dot(normal, lightVector);
	float NdotLWrap = (NdotL + wrap) / (1.0 + wrap);
	float scatter = smoothstep(0.0, scatterWidth, NdotLWrap) * smoothstep(scatterWidth * 2.0, scatterWidth, NdotLWrap);
	
	float waterDepth = distance(viewSpacePosition1.xyz, viewSpacePosition0.xyz); //How far is the water.
	
	//Beer's Law is what I'm using to determine water color.
	float fogAccum = 1.0 / exp(waterDepth * 0.2);
	
	vec3 waterFogColor = vec3(0.15, 0.4, 0.68);
	vec3 waterColor = mix(waterFogColor, waterFogColor * 2, vec3(scatter));
	
	color1 += waterFogColor * 2;
	color1 *= pow(vec3(0.7, 0.88, 1.0), vec3(waterDepth));
	color1 = mix(waterColor, color1, clamp01(fogAccum));
	show(color1);
	return color1;
}


void main() {
	float depth0 = GetDepth(texcoord);
	vec4  viewSpacePosition0 = CalculateViewSpacePosition(texcoord, depth0);
	
	Mask mask = CalculateMasks(Decode16(texture2D(colortex4, texcoord).a).g);
	
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
			
			normal = normalize((gbufferModelView * vec4(tangentNormal * transpose(tbnMatrix), 0.0)).xyz);
			
			
			refractedCoord = GetRefractedCoord(texcoord, viewSpacePosition0, tangentNormal);
			
			depth1 = GetTransparentDepth(refractedCoord);
			viewSpacePosition1 = CalculateViewSpacePosition(refractedCoord, depth1);
			
			alpha = texture2D(colortex2, refractedCoord).r;
			if(mask.water > 0.5) alpha = 0.1;
		}
	}
	
	vec3 sky = CalculateSky(viewSpacePosition1, 1.0 - alpha, false);
	
	if (depth0 >= 1.0) { gl_FragData[0] = vec4(EncodeColor(sky.rgb), 1.0); exit(); return; }
	
	
	float smoothness;
	float skyLightmap;
	Decode16(texture2D(colortex4, texcoord).b, smoothness, skyLightmap);
	
	vec3 color0 = vec3(0.0);
	vec3 color1 = vec3(0.0);
	
	if (mask.transparent > 0.5) {
		color0 = texture2D(colortex3, refractedCoord).rgb / alpha;
		
		if (any(isnan(color0))) color0 = vec3(0.0);
	} else {
		normal = DecodeNormal(encodedNormal.xy);
	}
	
	color1 = texture2D(colortex1, refractedCoord).rgb;
	
	color0 = mix(color1, color0, mask.transparent);
	if(mask.water > 0.5) color0 = waterFog(color1, normal, viewSpacePosition0, viewSpacePosition1, skyLightmap);
	
	
	ComputeReflectedLight(color0, viewSpacePosition0, normal, smoothness, skyLightmap, mask);
	
	
	if (depth1 >= 1.0) color0 = mix(sky.rgb, color0, alpha);
	
	color0 = mix(color0, sky.rgb, CalculateFogFactor(viewSpacePosition0, FOG_POWER));
	color1 = mix(color1, sky.rgb, CalculateFogFactor(viewSpacePosition1, FOG_POWER));
	
	if (depth1 < 1.0 && mask.transparent > 0.5) color0 = mix(color1, color0, alpha);
	
	
	gl_FragData[0] = vec4(EncodeColor(color0), 1.0);
	
	exit();
}
