float ComputeUniformlySoftShadows(in vec4 viewSpacePosition, in float sunlightCoeff) { // Soft shadows
	if (sunlightCoeff <= 0.01) return 0.0;
	
	float biasCoeff;
	
	vec3 shadowPosition = BiasShadowProjection((shadowProjection * shadowModelView * gbufferModelViewInverse * viewSpacePosition).xyz, biasCoeff) * 0.5 + 0.5;
	
	if (any(greaterThan(abs(shadowPosition.xyz - 0.5), vec3(0.5)))) return 1.0;
	
	float spread = (1.0 - biasCoeff) / shadowMapResolution;
	
	cfloat range       = 1.0;
	cfloat interval    = 1.0;
	cfloat sampleCount = pow(range / interval * 2.0 + 1.0, 2.0); // Calculating the sample count outside of the for-loop is generally faster.
	
	float sunlight = 0.0;
	
	for (float y = -range; y <= range; y += interval)
		for (float x = -range; x <= range; x += interval)
			sunlight += shadow2D(shadow, vec3(shadowPosition.xy + vec2(x, y) * spread, shadowPosition.z)).x;
	
	sunlight /= sampleCount; // Average the samples by dividing the sum by the sample count.
	
	return sunlightCoeff * pow2(sunlight);
}

#define ComputeShadows(x, y) ComputeUniformlySoftShadows(x, y)
