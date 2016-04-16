#version 120

#define SHADOW_MAP_BIAS 0.8
#define EXTENDED_SHADOW_DISTANCE
#define FORWARD_SHADING
#define CUSTOM_TIME_CYCLE

attribute vec4 mc_Entity;

uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

uniform vec3 cameraPosition;

uniform float frameTimeCounter;
uniform float sunAngle;

varying vec3 color;
varying vec2 texcoord;
varying vec2 lightmapCoord;

varying vec3 vertNormal;

#define PI 3.1415926
#define TIME frameTimeCounter

//#define WAVING_GRASS
#define WAVING_LEAVES
#define WAVING_WATER


vec4 GetWorldSpacePositionShadow() {
	return shadowModelViewInverse * shadowProjectionInverse * ftransform();
}

vec4 WorldSpaceToShadowProjection(in vec4 worldSpacePosition) {
	return shadowProjection * shadowModelView * worldSpacePosition;
}

vec3 GetWavingGrass(in vec3 position, in float magnitude) {
	vec3 wave = vec3(0.0);
	
	#ifdef WAVING_GRASS
	const float speed = 1.0;
	
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
	const float speed = 1.0;
	
	float intensity = (sin(((position.y + position.x)/2.0 + TIME * PI / ((88.0)))) * 0.05 + 0.15) * 0.35;
	
	float d0 = sin(TIME * 20.0 * PI / (122.0 * speed)) * 3.0 - 1.5;
	float d1 = sin(TIME * 20.0 * PI / (152.0 * speed)) * 3.0 - 1.5;
	float d2 = sin(TIME * 20.0 * PI / (192.0 * speed)) * 3.0 - 1.5;
	float d3 = sin(TIME * 20.0 * PI / (142.0 * speed)) * 3.0 - 1.5;
	
	wave.x += sin((TIME * 20.0 * PI / (16.0 * speed)) + (position.x + d0) * 0.5 + (position.z + d1) * 0.5 + position.y) * intensity;
	wave.z += sin((TIME * 20.0 * PI / (18.0 * speed)) + (position.z + d2) * 0.5 + (position.x + d3) * 0.5 + position.y) * intensity;
	wave.y += sin((TIME * 20.0 * PI / (10.0 * speed)) + (position.z + d2)       + (position.x + d3)                   ) * intensity / 2.0;
	#endif
	
	return wave * magnitude;
}

vec3 GetWavingWater(in vec3 position, in float magnitude) {
	vec3 wave = vec3(0.0);
	
	#ifdef WAVING_WATER
	float Distance = length(position.xz - cameraPosition.xz);
	
	float waveHeight = max(0.06 / max(Distance / 10.0, 1.0) - 0.006, 0.0);
	
	wave.y  = waveHeight * sin(PI * (TIME / 2.1 + position.x / 7.0  + position.z / 13.0));
	wave.y += waveHeight * sin(PI * (TIME / 1.5 + position.x / 11.0 + position.z / 5.0 ));
	wave.y -= waveHeight;
//	wave.y *= float(position.y - floor(position.y) > 0.15 || position.y - floor(position.y) < 0.005);
	#endif
	
	return wave * magnitude;
}

vec3 CalculateVertexDisplacements(in vec3 worldSpacePosition) {
	worldSpacePosition += cameraPosition.xyz;
	
	vec3 wave = vec3(0.0);
	
	float skylightWeight = lightmapCoord.t;
	float grassWeight    = float(fract(texcoord.t * 256.0) < 0.01);
	
	switch(int(mc_Entity.x)) {
		case 31:
		case 37:
		case 38:
		case 59:  wave += GetWavingGrass(worldSpacePosition, skylightWeight * grassWeight); break;
		case 18:
		case 161: wave += GetWavingLeaves(worldSpacePosition, skylightWeight); break;
		case 8:
		case 9:
		case 111: wave += GetWavingWater(worldSpacePosition, 1.0); break;
	}
	
	return wave;
}

vec4 BiasShadowProjection(in vec4 position) {
	float biasCoeff = length(position.xy);
	
	#ifdef EXTENDED_SHADOW_DISTANCE
		vec2 pos = abs(position.xy * 1.165);
		biasCoeff = pow(pow(pos.x, 8) + pow(pos.y, 8), 1.0 / 8.0);
	#endif
	
	biasCoeff = biasCoeff * SHADOW_MAP_BIAS + (1.0 - SHADOW_MAP_BIAS);
	
	position.z  += 0.002 * max(0.0, 1.0 - dot(vertNormal, vec3(0.0, 0.0, 1.0)));    // Offset the z-coordinate to fix shadow acne
	position.z  += 0.0005 / (abs(position.x) + 1.0);
	position.z  += 0.002 * pow(biasCoeff * 2.0, 2.0);
	
	position.xy /= biasCoeff;
	
	position.z  /= 4.0;    // Shrink the domain of the z-buffer. This counteracts the noticable issue where far terrain would not have shadows cast, especially when the sun was near the horizon
	
	return position;
}

void main() {
	color         = gl_Color.rgb;
	texcoord      = gl_MultiTexCoord0.st;
	lightmapCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).st;
	
	vertNormal    = gl_NormalMatrix * gl_Normal;
	
	
	vec4 position = GetWorldSpacePositionShadow();
	
	position.xyz += CalculateVertexDisplacements(position.xyz);
	
	gl_Position = BiasShadowProjection(WorldSpaceToShadowProjection(position));
	
	
	#ifdef FORWARD_SHADING
		if (abs(mc_Entity.x - 8.5) < 0.6) gl_Position.w = -1.0;
	#else
		if (abs(mc_Entity.x - 8.5) < 0.6) color.rgb *= 0.0;
	#endif
}