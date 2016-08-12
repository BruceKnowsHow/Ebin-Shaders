float GetShadowBias(vec2 shadowProjection) {
//	float scale = min(far, 140.0) / shadowDistance;
	float scale = 100.0 / shadowDistance;
	
	if (!biasShadowMap) return scale;
	
	shadowProjection /= scale;
	
//	float projScale = 1.165;
	float projScale = 1.0;
	
	return mix(1.0, length(shadowProjection) * projScale, SHADOW_MAP_BIAS) * scale;
}

vec2 BiasShadowMap(vec2 shadowProjection, out float biasCoeff) {
	biasCoeff = GetShadowBias(shadowProjection);
	return shadowProjection / biasCoeff;
}

vec2 BiasShadowMap(vec2 shadowProjection) {
	return shadowProjection / GetShadowBias(shadowProjection);
}

vec3 BiasShadowProjection(vec3 position, out float biasCoeff) {
	biasCoeff = GetShadowBias(position.xy);
	return position / vec3(vec2(biasCoeff), 4.0); // Apply bias to position.xy, shrink z-buffer
}

vec3 BiasShadowProjection(vec3 position) {
	return position / vec3(vec2(GetShadowBias(position.xy)), 4.0);
}
