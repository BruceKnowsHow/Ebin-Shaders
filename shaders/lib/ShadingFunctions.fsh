struct Shading {     // Contains scalar light levels without any color
	float normal;    // Coefficient of light intensity based on the dot product of the normal vector and the light vector
	float sunlight;
	float skylight;
	float torchlight;
	float ambient;
};

struct Lightmap {    // Contains vector light levels with color
	vec3 sunlight;
	vec3 skylight;
	vec3 ambient;
	vec3 torchlight;
};

vec4 ViewSpaceToWorldSpace(in vec4 viewSpacePosition) {
	return gbufferModelViewInverse * viewSpacePosition;
}

vec4 WorldSpaceToShadowSpace(in vec4 worldSpacePosition) {
	return shadowProjection * shadowModelView * worldSpacePosition;
}

float GetShadowBias(in vec2 shadowProjection) {
	#ifdef EXTENDED_SHADOW_DISTANCE
		shadowProjection *= 1.165;
		shadowProjection *= shadowProjection;    // These next 3 lines and the triple sqrt() get a squircular (bevelled square) length formula (rather than the generic circular length formula most shaders use).
		shadowProjection *= shadowProjection;
		shadowProjection *= shadowProjection;
		
		return sqrt(sqrt(sqrt(shadowProjection.x + shadowProjection.y))) * SHADOW_MAP_BIAS + (1.0 - SHADOW_MAP_BIAS);
	#else
		return length(shadowProjection) * SHADOW_MAP_BIAS + (1.0 - SHADOW_MAP_BIAS);
	#endif
}

vec4 BiasShadowProjection(in vec4 position, out float biasCoeff) {
	biasCoeff = GetShadowBias(position.xy);
	return position / vec4(vec2(biasCoeff), 4.0, 1.0);    // Apply bias to position.xy, shrink z-buffer
}

float GetNormalShading(in vec3 normal, in Mask mask) {
	float shading = dot(normal, lightVector);
	      shading = shading * (1.0 - mask.grass       ) + mask.grass       ;
	      shading = shading * (1.0 - mask.leaves * 0.5) + mask.leaves * 0.5;
	
	return shading;
}

float ComputeDirectSunlight(in vec4 position, in float normalShading) {
	if (normalShading <= 0.0) return 0.0;
	
	float biasCoeff;
	
	position = ViewSpaceToWorldSpace(position);
	position = WorldSpaceToShadowSpace(position);
	position = BiasShadowProjection(position, biasCoeff); 
	position = position * 0.5 + 0.5;
	
	if (position.x < 0.0 || position.x > 1.0
	||  position.y < 0.0 || position.y > 1.0
	||  position.z < 0.0 || position.z > 1.0
	    ) return 1.0;
	
	#ifdef SOFT_SHADOWS
		float sunlight = 0.0;
		float spread   = 1.0 * (1.0 - biasCoeff) / shadowMapResolution;
		
		const float range       = 1.0;
		const float interval    = 1.0;
		const float sampleCount = pow(range / interval * 2.0 + 1.0, 2.0);    // Calculating the sample count outside of the for-loop is generally faster.
		
		for (float i = -range; i <= range; i += interval)
			for (float j = -range; j <= range; j += interval)
				sunlight += shadow2D(shadow, vec3(position.xy + vec2(i, j) * spread, position.z)).x;
		
		sunlight /= sampleCount;    // Average the samples by dividing the sum by the sample count.
	#else
		float sunlight = shadow2D(shadow, position.xyz).x;
	#endif
	
	sunlight *= sunlight;    // Fatten the shadow up to soften its penumbra (default hardware-filtered penumbra does not have a satisfying penumbra curve)
	
	return sunlight;
}

vec3 CalculateShadedFragment(in Mask mask, in float torchLightmap, in float skyLightmap, in vec3 normal, in vec4 ViewSpacePosition) {
	Shading shading;
	shading.normal = GetNormalShading(normal, mask);
	
	shading.sunlight  = shading.normal;
	shading.sunlight *= ComputeDirectSunlight(ViewSpacePosition, shading.normal);
	
	shading.torchlight = 1.0 - pow(torchLightmap, 4.0);
	shading.torchlight = 1.0 / pow(shading.torchlight, 2.0) - 1.0;
	
	shading.skylight = pow(skyLightmap, 4.0);
	
	shading.ambient = 1.0;
	
	
	Lightmap lightmap;
	lightmap.sunlight = shading.sunlight * colorSunlight;
	
	lightmap.skylight = shading.skylight * sqrt(colorSkylight);
	
	lightmap.ambient = shading.ambient * vec3(1.0);
	
	lightmap.torchlight = shading.torchlight * vec3(1.00, 0.25, 0.05);
	
	
	vec3 composite = (
	    lightmap.sunlight   * 10.0
	+   lightmap.skylight   * 0.4
	+   lightmap.ambient    * 0.015
	+   lightmap.torchlight
	    );
	
	return composite;
}