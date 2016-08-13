vec2 SmoothNoiseCoord(vec2 coord) { // Reduce bilinear artifacts by biasing the lookup coordinate towards the pixel center
	coord *= noiseTextureResolution;
	coord  = floor(coord) + cubesmooth(fract(coord)) + 0.5;
	coord /= noiseTextureResolution;
	
	return coord;
}

float GetWave(vec2 coord) {
	return texture2D(noisetex, SmoothNoiseCoord(coord)).x;
}

float SharpenWave(float wave) {
	wave = 1.0 - abs(wave * 2.0 - 1.0);
	
	if (wave > 0.78) wave = 5.0 * wave - pow2(wave) * 2.5 - 1.6;
	
	return wave;
}

float GetWaves(vec3 position) {
	vec2 pos  = position.xz + position.y;
	     pos += TIME * WAVE_SPEED * vec2(1.0, -1.0);
	     pos *= 0.05;
	
	
	float weight, waves, weights;
	
	
	pos = pos / 2.1 - vec2(TIME * WAVE_SPEED / 30.0, TIME * 0.03);
	
	weight   = 4.0;
	waves   += GetWave(vec2(pos.x * 2.0, pos.y * 1.4 + pos.x * -2.1)) * weight;
	weights += weight;
	
	
	pos = pos / 1.5 + vec2(TIME / 20.0 * WAVE_SPEED, 0.0);
	
	weight   = 17.0;
	waves   += GetWave(vec2(pos.x, pos.y * 0.75 + pos.x * 1.1)) * weight;
	weights += weight;
	
	
	pos = pos / 1.5 - vec2(TIME / 55.0 * WAVE_SPEED, 0.0);
	
	weight   = 15.0;
	waves   += GetWave(vec2(pos.x, pos.y * 0.75 + pos.x * -1.7)) * weight;
	weights += weight;
	
	
	pos = pos / 1.9 + vec2(TIME / 155.0 * 0.8, 0.0);
	
	weight   = 29.0;
	waves   += SharpenWave(GetWave(vec2(pos.x, pos.y * 0.8 + pos.x * -1.7))) * weight;
	weights += weight;
	
	
	return waves / weights;
}

vec2 GetWaveDifferentials(vec3 position, cfloat scale) { // Get finite wave differentials for the world-space X and Z coordinates
	float a  = GetWaves(position                          );
	float aX = GetWaves(position + vec3(scale, 0.0,   0.0));
	float aY = GetWaves(position + vec3(  0.0, 0.0, scale));
	
	return a - vec2(aX, aY);
}


vec2 GetWaveNormals(vec4 viewSpacePosition, vec3 flatWorldNormal) {
	vec3 position = (gbufferModelViewInverse * vec4(viewSpacePosition.xyz, 0.0)).xyz;
	
	vec2 diff = GetWaveDifferentials(position + cameraPosition, 0.1);
	
	float viewVectorCoeff  = -dot(flatWorldNormal, normalize(position.xyz));
	      viewVectorCoeff /= clamp(length(viewSpacePosition.xyz) * 0.05, 1.0, 10.0);
	      viewVectorCoeff  = clamp01(viewVectorCoeff * 4.0);
	      viewVectorCoeff  = sqrt(viewVectorCoeff);
	
	return diff * WAVE_MULT * viewVectorCoeff;
}
