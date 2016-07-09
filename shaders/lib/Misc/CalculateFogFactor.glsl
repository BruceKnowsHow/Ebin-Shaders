float CalculateFogFactor(in vec4 viewSpacePosition, in float power) {
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
