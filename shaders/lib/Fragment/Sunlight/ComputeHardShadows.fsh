#define ComputeShadows(x, y) ComputeHardShadows(x, y)
float ComputeHardShadows(vec4 viewSpacePosition, float sunlightCoeff) {
	if (sunlightCoeff <= 0.01) return 0.0;
	
	vec3 shadowPosition = BiasShadowProjection((shadowProjection * shadowViewMatrix * gbufferModelViewInverse * viewSpacePosition).xyz) * 0.5 + 0.5;
	
	if (any(greaterThan(abs(shadowPosition.xyz - 0.5), vec3(0.5)))) return 1.0;
	
	return sunlightCoeff * pow2(shadow2D(shadow, shadowPosition.xyz).x);
}
