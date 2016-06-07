// Start of #include "/lib/Waving.vsh"

/* Prerequisites:

uniform float frameTimeCounter; 

// #include "/lib/Settings.glsl"

*/


vec3 GetWavingGrass(in vec3 position, in float magnitude) {
	vec3 wave = vec3(0.0);
	
	#ifdef WAVING_GRASS
		cfloat speed = 1.0;
		
		float intensity = sin((TIME * 20.0 * PI / (28.0)) + position.x + position.z) * 0.1 + 0.1;
		
		float d0 = sin(TIME * 20.0 * PI / (122.0 * speed)) * 3.0 - 1.5 + position.z;
		float d1 = sin(TIME * 20.0 * PI / (152.0 * speed)) * 3.0 - 1.5 + position.x;
		float d2 = sin(TIME * 20.0 * PI / (122.0 * speed)) * 3.0 - 1.5 + position.x;
		float d3 = sin(TIME * 20.0 * PI / (152.0 * speed)) * 3.0 - 1.5 + position.z;
		
		wave.x += sin((TIME * 20.0 * PI / (28.0 * speed)) + (position.x + d0) * 0.1 + (position.z + d1) * 0.1) * intensity;
		wave.z += sin((TIME * 20.0 * PI / (28.0 * speed)) + (position.z + d2) * 0.1 + (position.x + d3) * 0.1) * intensity;
	#endif
	
	return wave * magnitude;
}

vec3 GetWavingLeaves(in vec3 position, in float magnitude) {
	vec3 wave = vec3(0.0);
	
	#ifdef WAVING_LEAVES
		cfloat speed = 1.0;
		
		float intensity = (sin(((position.y + position.x) * 0.5 + TIME * PI / ((88.0)))) * 0.05 + 0.15) * 0.35;
		
		float d0 = sin(TIME * 20.0 * PI / (122.0 * speed)) * 3.0 - 1.5;
		float d1 = sin(TIME * 20.0 * PI / (152.0 * speed)) * 3.0 - 1.5;
		float d2 = sin(TIME * 20.0 * PI / (192.0 * speed)) * 3.0 - 1.5;
		float d3 = sin(TIME * 20.0 * PI / (142.0 * speed)) * 3.0 - 1.5;
		
		wave.x += sin((TIME * 20.0 * PI / (16.0 * speed)) + (position.x + d0) * 0.5 + (position.z + d1) * 0.5 + position.y) * intensity;
		wave.z += sin((TIME * 20.0 * PI / (18.0 * speed)) + (position.z + d2) * 0.5 + (position.x + d3) * 0.5 + position.y) * intensity;
		wave.y += sin((TIME * 20.0 * PI / (10.0 * speed)) + (position.z + d2)       + (position.x + d3)                   ) * intensity * 0.5;
	#endif
	
	return wave * magnitude;
}

vec3 GetWavingWater(in vec3 position, in float magnitude) {
	vec3 wave = vec3(0.0);
	
	#ifdef WAVING_WATER
		float Distance = length(position.xz - cameraPosition.xz);
		
		float waveHeight = max0(0.06 / max(Distance / 10.0, 1.0) - 0.006);
		
		wave.y  = waveHeight * sin(PI * (TIME / 2.1 + position.x / 7.0  + position.z / 13.0));
		wave.y += waveHeight * sin(PI * (TIME / 1.5 + position.x / 11.0 + position.z / 5.0 ));
		wave.y -= waveHeight;
		#if (!defined gbuffers_shadow)
			wave.y *= float(position.y - floor(position.y) > 0.15 || position.y - floor(position.y) < 0.005);
		#endif
	#endif
	
	return wave * magnitude;
}

// End of #include "/lib/Waving.vsh"