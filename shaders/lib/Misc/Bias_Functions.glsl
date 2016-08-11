float GetShadowBias(vec2 shadowProjection) {
	float scale = clamp(far, 64.0, 140.0) / shadowDistance;
	
	if (!biasShadowMap) return scale;
	
	shadowProjection /= scale;
	
	#ifdef EXTENDED_SHADOW_DISTANCE
		float projScale = 1.165;
		
		return mix(1.0, length8(shadowProjection) * projScale, SHADOW_MAP_BIAS) * scale;
	#else
		return mix(1.0, length (shadowProjection)            , SHADOW_MAP_BIAS) * scale;
	#endif
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
