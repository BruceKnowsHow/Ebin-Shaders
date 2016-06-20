float CalculateDirectSunlight(in vec4 viewSpacePosition, in float sunlight) {
	if (sunlight <= 0.01) return 0.0;
	
	float biasCoeff;
	
	vec3 shadowPosition = BiasShadowProjection((shadowProjection * shadowModelView * gbufferModelViewInverse * viewSpacePosition).xyz, biasCoeff) * 0.5 + 0.5;
	
	if (any(greaterThan(abs(shadowPosition.xyz - 0.5), vec3(0.5)))) return 1.0;
	
	return sunlight * ComputeShadows(shadowPosition.xyz, biasCoeff);
}
