#version 120
#define hand_vsh true
#define ShaderStage -10

uniform mat4 gbufferProjectionInverse;

attribute vec4 mc_Entity;
attribute vec4 at_tangent;
attribute vec4 mc_midTexCoord;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

uniform vec3  cameraPosition;
uniform float rainStrength;
uniform float frameTimeCounter;

varying vec3 color;
varying vec2 texcoord;
varying vec2 lightmapCoord;

varying vec3 vertNormal;
varying mat3 tbnMatrix;
varying vec2 vertLightmap;

varying float materialIDs;
varying float encodedMaterialIDs;

varying vec4 viewSpacePosition;
varying vec3 worldPosition;


//#include include/PostHeader.vsh"
uniform vec3 sunPosition;
uniform vec3 upPosition;

varying vec3 lightVector;

varying float timeDay;
varying float timeNight;
varying float timeHorizon;

varying vec3 colorSunlight;
varying vec3 colorSkylight;

float clamp01(in float x) {
	return clamp(x, 0.0, 1.0);
}

#define PI 3.1415926
#define TIME frameTimeCounter
//#include include/PostHeader.vsh"

#define RECALCULATE_DISPLACED_NORMALS

//#define WAVING_GRASS
#define WAVING_LEAVES
#define WAVING_WATER


vec2 GetDefaultLightmap(in vec2 lightmapCoord) { // Gets the lightmap from the default lighting engine, ignoring any texture pack lightmap. First channel is torch lightmap, second channel is sky lightmap.
	return clamp((lightmapCoord * 1.032) - 0.032, 0.0, 1.0).st; // Default lightmap texture coordinates work somewhat as lightmaps, however they need to be adjusted to use the full range of 0.0-1.0
}

float GetMaterialIDs() { // Gather material masks
	#ifdef GBUFFERS_HAND_VERTEX
	return 5.0;
	#endif
	
	float materialID;
	
	switch(int(mc_Entity.x)) {
		case 31:                     // Tall Grass
		case 37:                     // Dandelion
		case 38:                     // Rose
		case 59:                     // Wheat
		case 83:                     // Sugar Cane
		case 175:                    // Double Tall Grass
		    materialID = 2.0; break; // Grass
		case 18:                     // Generic leaves
		case 106:                    // Vines
		case 161:                    // New leaves
		    materialID = 3.0; break; // Leaves
		case 8:
		case 9:
		    materialID = 4.0; break; // Water
		case 79:
		    materialID = 5.0; break; // Ice
		default:	materialID = 1.0;
	}
	
	return materialID;
}

float EncodeMaterialIDs(in float materialIDs, in float bit0, in float bit1, in float bit2, in float bit3) {
	materialIDs += 128.0 * bit0;
	materialIDs +=  64.0 * bit1;
	materialIDs +=  32.0 * bit2;
	materialIDs +=  16.0 * bit3;
	
	materialIDs += 0.1;
	materialIDs /= 255.0;
	materialIDs  = 1.0 - materialIDs; // MaterialIDs are sent through the pipeline inverted so that when they're decoded, sky pixels (which are always written as 0.0 in certain situations) will be 1.0
	
	return materialIDs;
}


vec4 GetWorldSpacePosition() {
	return gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
}

vec4 WorldSpaceToProjectedSpace(in vec4 worldSpacePosition) {
	return gl_ProjectionMatrix * gbufferModelView * worldSpacePosition;
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
	wave.y += sin((TIME * 20.0 * PI / (10.0 * speed)) + (position.z + d2)       + (position.x + d3)                   ) * intensity * 0.5;
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
	wave.y *= float(position.y - floor(position.y) > 0.15 || position.y - floor(position.y) < 0.005);
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

void CalculateTBN(in vec3 position, out mat3 tbnMatrix, out vec3 normal) {
	vec3 tangent  = normalize(                  at_tangent.xyz);
	vec3 binormal = normalize(-cross(gl_Normal, at_tangent.xyz));
	
	#ifdef RECALCULATE_DISPLACED_NORMALS
	tangent  += CalculateVertexDisplacements(position +  tangent) * 0.3;
	binormal += CalculateVertexDisplacements(position + binormal) * 0.3;
	#endif
	
	tangent  = normalize(gl_NormalMatrix * tangent);
	binormal = normalize(gl_NormalMatrix * binormal);
	
	normal = cross(-tangent, binormal);
	
	tbnMatrix = mat3(
	tangent.x, binormal.x, normal.x,
	tangent.y, binormal.y, normal.y,
	tangent.z, binormal.z, normal.z);
}


void main() {
	color         = gl_Color.rgb;
	texcoord      = gl_MultiTexCoord0.st;
	lightmapCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).st;
	
	vertLightmap       = GetDefaultLightmap(lightmapCoord);
	materialIDs        = GetMaterialIDs();
	encodedMaterialIDs = EncodeMaterialIDs(materialIDs, 0.0, 0.0, 0.0, 0.0);
	
	
	vec4 position = GetWorldSpacePosition();
	
	position.xyz += CalculateVertexDisplacements(position.xyz);
	
	gl_Position   = WorldSpaceToProjectedSpace(position);
	
	
	CalculateTBN(position.xyz, tbnMatrix, vertNormal);
	
	worldPosition      = position.xyz + cameraPosition;
	viewSpacePosition  = gbufferModelView * position;
	
//#include "include/PostCalculations.vsh"
	vec3 sunVector = normalize(sunPosition); //Engine-time overrides will happen by modifying sunVector
	
	lightVector = sunVector * mix(1.0, -1.0, float(dot(sunVector, upPosition) < 0.0));
	
	
	float sunUp   = dot(sunVector, normalize(upPosition));
	
	timeDay     = sin( sunUp * PI * 0.5);
	timeNight   = sin(-sunUp * PI * 0.5);
	timeHorizon = pow(1 + timeDay * timeNight, 4.0);
	
	float horizonClip = max(0.0, 0.9 - timeHorizon) / 0.9;
	
	timeDay = clamp01(timeDay * horizonClip);
	timeNight = clamp01(timeNight * horizonClip);
	
	vec3 sunlightDay =
	vec3(1.0, 1.0, 1.0);
	
	vec3 sunlightNight =
	vec3(0.43, 0.65, 1.0) * 0.025;
	
	vec3 sunlightHorizon =
	vec3(1.00, 0.50, 0.00);
	
	colorSunlight  = sunlightDay * timeDay + sunlightNight * timeNight + sunlightHorizon * timeHorizon;
//	colorSunlight *= mix(vec3(1.0), sunlightHorizon, timeHorizon);
	
	
	const vec3 skylightDay =
	vec3(0.24, 0.58, 1.00);
	
	const vec3 skylightNight =
	vec3(0.25, 0.5, 1.0) * 0.025;
	
	const vec3 skylightHorizon =
	vec3(0.29, 0.48, 1.0) * 0.01;
	
	colorSkylight = skylightDay * timeDay + skylightNight * timeNight + skylightHorizon * timeHorizon;
//#include "include/PostCalculations.vsh"
}