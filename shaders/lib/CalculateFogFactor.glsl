float CalculateFogFactor(in vec4 position, in float power) {
	#ifndef FOG_ENABLED
	return 0.0;
	#endif
	
	float fogFactor = length(position.xyz);
		  fogFactor = max(fogFactor - gl_Fog.start, 0.0);
		  fogFactor /= far - gl_Fog.start;
		  fogFactor = pow(fogFactor, power);
		  fogFactor = clamp(fogFactor, 0.0, 1.0);
	
	return fogFactor;
}

float GetSkyAlpha(in float fogVolume, in float fogFactor) {
	return min(fogVolume * fogFactor + pow(fogFactor, 6) * float(Volumetric_Fog), 1.0);
}