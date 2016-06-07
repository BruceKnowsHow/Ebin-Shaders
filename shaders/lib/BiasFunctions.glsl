// Start of #include "/lib/BiasFunctions.glsl"

/* Prerequisites:

// #include "/lib/Settings.glsl"
// #include "/lib/Util.glsl"

*/


float GetShadowBias(in vec2 shadowProjection) {
	if (!biasShadowMap) return 1.0;

	#ifdef EXTENDED_SHADOW_DISTANCE
		shadowProjection *= 1.165;
		
		return length8(shadowProjection) * SHADOW_MAP_BIAS + (1.0 - SHADOW_MAP_BIAS);
	#else
		return length (shadowProjection) * SHADOW_MAP_BIAS + (1.0 - SHADOW_MAP_BIAS);
	#endif
}

vec2 BiasShadowMap(in vec2 shadowProjection, out float biasCoeff) {
	biasCoeff = GetShadowBias(shadowProjection);
	return shadowProjection / biasCoeff;
}

vec2 BiasShadowMap(in vec2 shadowProjection) {
	return shadowProjection / GetShadowBias(shadowProjection);
}

vec3 BiasShadowProjection(in vec3 position, out float biasCoeff) {
	biasCoeff = GetShadowBias(position.xy);
	return position / vec3(vec2(biasCoeff), 4.0); // Apply bias to position.xy, shrink z-buffer
}

vec3 BiasShadowProjection(in vec3 position) {
	return position / vec3(vec2(GetShadowBias(position.xy)), 4.0);
}

// End of #include "/lib/BiasFunctions.glsl"