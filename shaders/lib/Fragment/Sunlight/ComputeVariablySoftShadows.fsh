vec2 GetDitherred2DNoise(in vec2 coord, in float n) { // Returns a random noise pattern ranging {-1.0 to 1.0} that repeats every n pixels
	coord *= vec2(viewWidth, viewHeight);
	coord  = mod(coord, vec2(n));
	coord /= noiseTextureResolution;
	return texture2D(noisetex, coord).xy;
}

float ComputeShadows(in vec3 position, in float biasCoeff) { // Variable softness shadows (PCSS)
	float vpsSpread = 0.4 / biasCoeff;
	
	vec2 randomAngle = GetDitherred2DNoise(texcoord, 64.0).xy * PI * 2.0;
	
	mat2 blockerRotation = mat2(
		cos(randomAngle.x), -sin(randomAngle.x),
	    sin(randomAngle.y),  cos(randomAngle.y)); //Random Rotation Matrix for blocker, high noise
	
	mat2 pcfRotation = mat2(
		cos(randomAngle.x), -sin(randomAngle.x),
		sin(randomAngle.x),  cos(randomAngle.x)); //Random Rotation Matrix for blocker, high noise
	
	float range       = 1.0;
	float sampleCount = pow(range * 2.0 + 1.0, 2.0);
	
	float avgDepth = 0.0;
	//Blocker Search
	for(float y = -range; y <= range; y++) {
		for(float x = -range; x <= range; x++) {
			vec2 lookupPosition = position.xy + vec2(x, y) * 8.0 / shadowMapResolution * blockerRotation * vpsSpread;
			float depthSample = texture2DLod(shadowtex1, lookupPosition, 0).x;
			
			avgDepth += pow(clamp(position.z - depthSample, 0.0, 1.0), 1.7);
		}
	}
	
	avgDepth /= sampleCount;
	avgDepth  = sqrt(avgDepth);
	
	float spread = avgDepth * 0.02 * vpsSpread + 0.45 / shadowMapResolution;
	
	range       = 2.0;
	sampleCount = pow(range * 2.0 + 1.0, 2.0);
	
	float sunlight = 0.0;
	
	//PCF Blur
	for (float y = -range; y <= range; y++) {
		for (float x = -range; x <= range; x++) {
			vec2 coord = vec2(x, y) * pcfRotation;
			
			sunlight += shadow2D(shadow, vec3(coord * spread + position.st, position.z)).x;
		}
	}
	
	return sunlight / sampleCount;
}
