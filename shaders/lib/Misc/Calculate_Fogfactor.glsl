float CalculateFogFactor(vec4 viewSpacePosition, float power) {
	if (-viewSpacePosition.z > far * 1.875) return 1.0;
	
#ifndef FOG_ENABLED
	return 0.0;
#endif
	
	float fogFactor  = length(viewSpacePosition.xyz);
		  fogFactor  = max0(fogFactor - gl_Fog.start);
		  fogFactor /= far - gl_Fog.start;
		  fogFactor  = pow(fogFactor, power);
		  fogFactor  = clamp01(fogFactor);
	
	return fogFactor;
}
