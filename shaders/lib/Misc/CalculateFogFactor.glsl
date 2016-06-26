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

float GetSkyAlpha(in float fogVolume, in float fogFactor) {
	float alpha = fogVolume * fogFactor;
	
#ifdef VOLUMETRIC_FOG
	alpha += pow(fogFactor, 6);
#endif
	
	return min1(alpha);
}
