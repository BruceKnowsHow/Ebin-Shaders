float ComputeShadows(in vec3 position, in float biasCoeff) { // Soft shadows
	float spread = (1.0 - biasCoeff) / shadowMapResolution;
	
	cfloat range       = 1.0;
	cfloat interval    = 1.0;
	cfloat sampleCount = pow(range / interval * 2.0 + 1.0, 2.0); // Calculating the sample count outside of the for-loop is generally faster.
	
	float sunlight = 0.0;
	
	for (float y = -range; y <= range; y += interval)
		for (float x = -range; x <= range; x += interval)
			sunlight += shadow2D(shadow, vec3(position.xy + vec2(x, y) * spread, position.z)).x;
	
	sunlight /= sampleCount; // Average the samples by dividing the sum by the sample count.
	
	return pow2(sunlight);
}
