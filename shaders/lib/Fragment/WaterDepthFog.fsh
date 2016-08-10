vec3 waterFog(vec3 color, vec4 viewSpacePosition0, vec4 viewSpacePosition1) {
	float waterDepth = distance(viewSpacePosition1.xyz, viewSpacePosition0.xyz); // Depth of the water volume
	
	if (isEyeInWater == 1) waterDepth = length(viewSpacePosition0);
	
	// Beer's Law
	float fogAccum = exp(-waterDepth * 0.2);
	
	vec3 waterDepthColors = vec3(0.0015, 0.004, 0.0098) * sunlightColor;
	vec3 waterFogColor = vec3(0.1, 0.5, 0.8);
	
	color *= pow(vec3(0.7, 0.88, 1.0), vec3(waterDepth));
	color  = mix(waterDepthColors, color, clamp01(fogAccum));

	return color;
}
