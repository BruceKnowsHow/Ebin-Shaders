float GetShadowScale() {
	float scale = far;
	
#ifndef EXTENDED_SHADOW_DISTANCE
	scale = clamp(scale, 64.0, 140.0);
#endif
	
	return scale / shadowDistance;
}

float GetShadowBias(vec2 shadowProjection) {
	float scale = GetShadowScale();
	
	return mix(1.0, length(shadowProjection) / scale * 1.15, SHADOW_MAP_BIAS) * scale;
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
	return position / vec3(vec2(biasCoeff), 6.0); // Apply bias to position.xy, shrink z-buffer
}

vec3 BiasShadowProjection(vec3 position) {
	return position / vec3(vec2(GetShadowBias(position.xy)), 6.0);
}
