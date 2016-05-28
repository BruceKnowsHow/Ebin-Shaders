
// Start of #include "/lib/WaterWaves.fsh"


vec2 SmoothNoiseCoord(in vec2 coord) { // Reduce bilinear artifacts by biasing the lookup coordinate towards the pixel center
	coord *= noiseTextureResolution;
	coord  = floor(coord) + cubesmooth(fract(coord)) + 0.5;
	coord /= noiseTextureResolution;
	
	return coord;
}

float SharpenWave(in float wave) {
	wave = 1.0 - abs(wave * 2.0 - 1.0);
	
	if (wave > 0.78) wave = 5.0 * wave - pow2(wave) * 2.5 - 1.6;
	
	return wave;
}

float GetWave(in vec2 coord) {
	return texture2D(noisetex, SmoothNoiseCoord(coord)).x;
}

float GetWaves(vec3 position, cfloat speed) {
	vec2 pos  = position.xz + position.y;
	     pos += TIME * speed * vec2(1.0, -1.0);
	     pos *= 0.05;
	
	
	float weight, waves, weights;
	
	
	pos = pos / 2.1 - vec2(TIME * speed / 30.0, TIME * 0.03);
	
	weight   = 4.0;
	waves   += GetWave(vec2(pos.x * 2.0, pos.y * 1.4 + pos.x * -2.1)) * weight;
	weights += weight;
	
	
	pos = pos / 1.5 + vec2(TIME / 20.0 * speed, 0.0);
	
	weight   = 17.0;
	waves   += GetWave(vec2(pos.x, pos.y * 0.75 + pos.x * 1.1)) * weight;
	weights += weight;
	
	
	pos = pos / 1.5 - vec2(TIME / 55.0 * speed, 0.0);
	
	weight   = 15.0;
	waves   += GetWave(vec2(pos.x, pos.y * 0.75 + pos.x * -1.7)) * weight;
	weights += weight;
	
	
	pos = pos / 1.9 + vec2(TIME / 155.0 * 0.8, 0.0);
	
	weight   = 29.0;
	waves   += SharpenWave(GetWave(vec2(pos.x, pos.y * 0.8 + pos.x * -1.7))) * weight;
	weights += weight;
	
	
	return waves * WAVE_MULT / weights;
}

vec2 GetWaveDifferentials(in vec3 position) { // Get finite wave differentials for the world-space X and Z coordinates
	cfloat speed = 0.35;
	
	float a  = GetWaves(position                      , speed);
	float aX = GetWaves(position + vec3(0.1, 0.0, 0.0), speed);
	float aY = GetWaves(position + vec3(0.0, 0.0, 0.1), speed);
	
	return a - vec2(aX, aY);
}


vec3 GetWaveNormals(in vec4 viewSpacePosition, in vec3 baseNormal, in mat3 tbnMatrix) {
	vec3 position = (gbufferModelViewInverse * viewSpacePosition).xyz + cameraPosition;
	
	vec2 diff = GetWaveDifferentials(position);
	
	vec3 normal;
	
	float viewVectorCoeff  = -dot(baseNormal, normalize(viewSpacePosition.xyz));
	      viewVectorCoeff /= clamp(length(viewSpacePosition.xyz) * 0.05, 1.0, 10.0);
	      viewVectorCoeff  = clamp01(viewVectorCoeff * 4.0);
	      viewVectorCoeff  = sqrt(viewVectorCoeff);
	
	normal.xy = diff * viewVectorCoeff;
	normal.z  = sqrt(1.0 - pow2(normal.x) - pow2(normal.y)); // Solve the equation "length(normal.xyz) = 1.0" for normal.z
	
	return normalize(normal * tbnMatrix);
}



// End of #include "/lib/WaterWaves.fsh"
