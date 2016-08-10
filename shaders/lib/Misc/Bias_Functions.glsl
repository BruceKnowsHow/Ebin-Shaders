float GetShadowBias(vec2 shadowProjection) {
	float scale  = 140.0 / shadowDistance;
	      scale *= min(far / 256.0, 1.0); // When the view-distance < 4, zoom in to improve shadow quality
	
	if (!biasShadowMap) return scale;
	
	shadowProjection /= scale;
	
	#ifdef EXTENDED_SHADOW_DISTANCE
		return mix(1.0, length8(shadowProjection * 1.165), SHADOW_MAP_BIAS) * scale;
	#else
		return mix(1.0, length (shadowProjection), SHADOW_MAP_BIAS) * scale;
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
