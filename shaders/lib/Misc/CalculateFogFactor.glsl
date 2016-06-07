// Start of #include "/lib/Misc/CalculateFogFactor.glsl"

/* Prerequisites:

uniform float far;

// #include "/lib/Settings.glsl"
// #include "/lib/Utility.glsl"

*/


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
	return min1(fogVolume * fogFactor + pow(fogFactor, 6) * float(Volumetric_Fog));
}

// End of #include "/lib/Misc/CalculateFogFactor.glsl"