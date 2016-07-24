#ifndef GI_ENABLED
	#define ComputeGlobalIllumination(a, b, c, d, e, f) vec3(0.0)
#elif GI_MODE == 1
vec3 ComputeGlobalIllumination(in vec4 position, in vec3 normal, in float skyLightmap, const in float radius, in vec2 noise, in Mask mask) {
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
		
		viewNormalCoeff = viewNormalCoeff * (1.0 - GI_TRANSLUCENCE) + GI_TRANSLUCENCE;
		
		shadowNormalCoeff = sqrt(shadowNormalCoeff);
		
		vec3 flux = pow(texture2DLod(shadowcolor, mapPos, sampleLOD).rgb, vec3(2.2));
		
		GI += flux * viewNormalCoeff * shadowNormalCoeff * distanceCoeff;
	}
	
	GI /= GI_SAMPLE_COUNT;
	
	return GI * lightMult * brightness; // brightness is constant for all pixels for all samples. lightMult is not constant over all pixels, but is constant over each pixels' samples.
}

#elif GI_MODE == 2
vec3 ComputeGlobalIllumination(in vec4 position, in vec3 normal, in float skyLightmap, const in float radius, in vec2 noise, in Mask mask) {
	float lightMult = skyLightmap;
	
	#ifdef GI_BOOST
		float sunlight  = GetLambertianShading(normal, mask);
		      sunlight *= skyLightmap;
		      sunlight  = ComputeHardShadows(position, sunlight);
		
		lightMult = 1.0 - sunlight * 4.0;
	#endif
	
	if (lightMult < 0.05) return vec3(0.0);
	
	float LodCoeff = clamp(1.0 - length(position.xyz) / shadowDistance, 0.0, 1.0);
	
	float depthLOD	= 2.0 * LodCoeff * 1.0;
	float sampleLOD	= 5.0 * LodCoeff * 1.0;
	
	vec4 shadowViewPosition = shadowModelView * gbufferModelViewInverse * position;    // For linear comparisons (GI_MODE = 1)
	
	position = shadowProjection * shadowViewPosition; // "position" now represents shadow-projection-space position. Position can also be used for exponential comparisons (GI_MODE = 2)
	normal   = -(shadowModelView * gbufferModelViewInverse * vec4(normal, 0.0)).xyz; // Convert the normal so it can be compared with the shadow normal samples
	
	
	float biasCoeff = GetShadowBias(position.xy);
	
	float  brightness = 100.0 * pow(radius, sqrt(2.0)) * GI_BRIGHTNESS * SUN_LIGHT_LEVEL;
	cfloat scale      = radius / 256.0;
	
	vec3 GI = vec3(0.0);
	
	noise *= scale;
	
	for(float x = -1.0; x <= 1.0; x += 1.0 / 4.0) {
		for(float y = -1.0; y <= 1.0; y += 1.0 / 4.0) {
			vec2 offset = (vec2(y, x) + noise) * scale;
			if (offset.x == 0.0 && offset.y == 0.0) continue; 
			
			vec4 samplePos = vec4(position.xy + offset, position.zw);
			
			vec2 mapPos = BiasShadowMap(samplePos.xy) * 0.5 + 0.5;
			
			samplePos.z = texture2DLod(shadowtex1, mapPos, depthLOD).x;
			samplePos.z = samplePos.z * 8.0 - 4.0; // Convert range from unsigned to signed and undo z-shrinking
			
			samplePos = shadowProjectionInverse * samplePos; // Convert sample position to shadow-view-space for a linear comparison against the pixel's position
			
			vec3 sampleDiff = shadowViewPosition.xyz - samplePos.xyz;
			
			float distanceCoeff = lengthSquared(sampleDiff);
			
			vec3 sampleDir = normalize(sampleDiff);
			
			vec3 shadowNormal;
			     shadowNormal.xy = texture2DLod(shadowcolor1, mapPos, sampleLOD).xy * 2.0 - 1.0;
			     shadowNormal.z  = sqrt(1.0 - lengthSquared(shadowNormal.xy));
			
			float viewNormalCoeff   = max0(dot(      normal, sampleDir));
			float shadowNormalCoeff = max0(dot(shadowNormal, sampleDir));
			
			viewNormalCoeff = viewNormalCoeff * (1.0 - GI_TRANSLUCENCE) + GI_TRANSLUCENCE;
			
			vec3 flux = pow(texture2DLod(shadowcolor, mapPos, sampleLOD).rgb, vec3(2.2));
			
			float sampleCoeff = viewNormalCoeff * shadowNormalCoeff;
				  sampleCoeff = pow(sampleCoeff, 1.0 + 4.0 - 4.0 * min1(distanceCoeff));
			
			GI += flux * sampleCoeff / max(distanceCoeff, 1.0) * 0.2;
			GI += flux * sampleCoeff / max(distanceCoeff, pow(radius, 2)) * 0.5;
		}
	}
	
	GI /= pow2(2.0 * 4.0 + 1.0);
	
	return GI * lightMult * brightness; // brightness is constant for all pixels for all samples. lightMult is not constant over all pixels, but is constant over each pixels' samples.
}

#else
vec3 ComputeGlobalIllumination(in vec4 position, in vec3 normal, in float skyLightmap, const in float radius, in vec2 noise, in Mask mask) {
	float lightMult = skyLightmap;
	
	#ifdef GI_BOOST
		float sunlight  = GetLambertianShading(normal, mask);
		      sunlight *= skyLightmap;
		      sunlight  = ComputeHardShadows(position, sunlight);
		
		lightMult = 1.0 - sunlight * 4.0;
	#endif
	
	if (lightMult < 0.05) return vec3(0.0);
	
	vec4 shadowViewPosition = shadowModelView * gbufferModelViewInverse * position;    // For linear comparisons (GI_MODE = 1)
	
	position = shadowProjection * shadowViewPosition; // "position" now represents shadow-projection-space position. Position can also be used for exponential comparisons (GI_MODE = 2)
	normal = vec3(-1.0, -1.0,  1.0) * (shadowModelView * gbufferModelViewInverse * vec4(normal, 0.0)).xyz; // Convert the normal so it can be compared with the shadow normal samples
	
	float brightness = 0.000075 * pow(radius, 2) * GI_BRIGHTNESS * SUN_LIGHT_LEVEL;
	cfloat scale  = radius / 1024.0;
	
	vec3 GI = vec3(0.0);
	noise *= scale;
	
	#include "/lib/Samples/GI.glsl"
	
	for (int i = 0; i < GI_SAMPLE_COUNT; i++) {
		vec2 offset = samples[i] * scale + noise;
		
		vec4 samplePos = vec4(position.xy + offset, 0.0, 1.0);
		
		vec2 mapPos = BiasShadowMap(samplePos.xy) * 0.5 + 0.5;
		
		samplePos.z = texture2DLod(shadowtex1, mapPos, 0.0).x;
		samplePos.z = samplePos.z * 8.0 - 4.0;    // Convert range from unsigned to signed and undo z-shrinking
		
		vec3 sampleDiff = position.xyz - samplePos.xyz;
		
		float distanceCoeff = lengthSquared(sampleDiff); // Inverse-square law
		      distanceCoeff = 1.0 / max(distanceCoeff, 2.5e-4);
		
		vec3 sampleDir = normalize(sampleDiff);
		
		vec3 shadowNormal;
		     shadowNormal.xy = texture2DLod(shadowcolor1, mapPos, 0.0).xy * 2.0 - 1.0;
		     shadowNormal.z  = -sqrt(1.0 - lengthSquared(shadowNormal.xy));
		
		float viewNormalCoeff   = max0(dot(normal, sampleDir));
		float shadowNormalCoeff = max0(dot(shadowNormal, sampleDir));
		
		viewNormalCoeff = viewNormalCoeff * (1.0 - GI_TRANSLUCENCE) + GI_TRANSLUCENCE;
		
		vec3 flux = pow(texture2DLod(shadowcolor, mapPos, 2).rgb, vec3(2.2));
		
		GI += flux * viewNormalCoeff * shadowNormalCoeff * distanceCoeff;
	}
	
	GI /= GI_SAMPLE_COUNT;
	
	return GI * lightMult * brightness; // brightness is constant for all pixels for all samples. lightMult is not constant over all pixels, but is constant over each pixels' samples.
}
#endif
