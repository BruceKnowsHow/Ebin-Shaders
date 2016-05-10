#version 120

/* DRAWBUFFERS:2306 */

#define ShaderStage -1

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D noisetex;

uniform sampler2DShadow shadow;
uniform sampler2D shadowtex1;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

uniform float frameTimeCounter;
uniform float far;

uniform float viewWidth;
uniform float viewHeight;

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

#include "/lib/Settings.glsl"
#include "/lib/Util.glsl"
#include "/lib/GlobalCompositeVariables.fsh"
#include "/lib/CalculateFogFactor.glsl"
#include "/lib/DebugSetup.glsl"
#ifdef FORWARD_SHADING
#include "/lib/Masks.glsl"
#include "/lib/ShadingFunctions.fsh"
#endif


vec4 GetDiffuse() {
	vec4 diffuse = vec4(color.rgb, 1.0);
	     diffuse *= texture2D(texture, texcoord);
	
	return diffuse;
}

void GetWaveDifferential(inout vec2 diff, in vec2 pos, in float wavelength, in float amplitude, in float speed, in vec2 direction) {
	direction  = normalize(direction);
	wavelength = 1.0 / wavelength * PI * 2.0;
	
	amplitude *= 0.1;
	
	float wave = wavelength * amplitude * cos(dot(pos, direction) * wavelength + TIME * speed);
	
	diff += wave * direction;
}

void GetWaveDifferentials(in vec3 position, out vec2 diff) {
	diff = vec2(0.0);
	
	GetWaveDifferential(diff, position.xz, 1.00, 0.010, 2.0, vec2( 0.40, 0.80));
	GetWaveDifferential(diff, position.xz, 5.00, 0.010, 3.0, vec2( 0.30, 0.10));
	GetWaveDifferential(diff, position.xz, 1.00, 0.010, 5.0, vec2( 0.25, 0.16));
	GetWaveDifferential(diff, position.xz, 2.00, 0.020, 4.0, vec2(-0.80, 0.56));
	GetWaveDifferential(diff, position.xz, 3.50, 0.005, 2.1, vec2(-1.00, 0.10));
	GetWaveDifferential(diff, position.xz, 0.79, 0.003, 2.5, vec2( 1.60, 0.10));
	GetWaveDifferential(diff, position.xz, 1.40, 0.015, 1.5, vec2( 0.60,-0.50));
}

vec2 smoothNoiseCoord(in vec2 coord) { // Reduce bilinear artifacts by biasing the lookup coordinate towards the pixel center
	return floor(coord) + cubesmooth(fract(coord)) + 0.5;
}

float GetFractalWaveHeight(in vec2 coord, const vec2 wavelength, const vec2 speed, const vec2 direction, const float amplitude, inout float totalAmplitude) {
	const float angle = atan(normalize(direction).x, normalize(direction).y);
	
	coord += TIME * speed;
	rotate(coord, angle);
	coord /= wavelength;
	coord  = smoothNoiseCoord(coord);
	coord *= noiseTextureResolutionInverse;
	
	float wave = texture2D(noisetex, coord).x;
	
	totalAmplitude += amplitude;
	
	return wave * amplitude;
}

float GetFractalWaves(vec3 position) {
	float waves = 0.0;
	float totalAmplitude = 0.0;
	
	vec2 coord  = position.xz;
	     coord -= position.y * vec2(0.5, 0.866);
	
	waves += GetFractalWaveHeight(coord, vec2(0.38, 0.15), vec2( 1.00,  0.57), vec2( 1.00, -0.40), 0.85, totalAmplitude);
	waves += GetFractalWaveHeight(coord, vec2(0.29, 0.53), vec2(-0.63,  0.86), vec2(-0.10,  0.50), 2.49, totalAmplitude);
	waves += GetFractalWaveHeight(coord, vec2(0.94, 1.16), vec2( 0.76, -0.54), vec2( 0.47,  1.50), 6.93, totalAmplitude);
	waves += GetFractalWaveHeight(coord, vec2(1.57, 1.24), vec2(-0.39, -0.66), vec2(-0.90, -1.80), 8.54, totalAmplitude);
	
	return waves / totalAmplitude;
}

void GetFractalWaveDifferentials(in vec3 position, out vec2 diff) { // Get finite wave differentials for the world-space X and Z coordinates
	float a  = GetFractalWaves(position);
	float aX = GetFractalWaves(position + vec3(0.1, 0.0, 0.0));
	float aY = GetFractalWaves(position + vec3(0.0, 0.0, 0.1));
	
	diff = a - vec2(aX, aY);
}

vec3 GetWaveNormals(in vec3 position) {
	vec2 diff;
	
	GetFractalWaveDifferentials(position, diff);
	
	vec3 normal;
	
	float viewVectorCoeff  = -dot(vertNormal, normalize(viewSpacePosition.xyz));
	      viewVectorCoeff /= clamp(length(viewSpacePosition.xyz) * 0.05, 1.0, 10.0);
	      viewVectorCoeff  = clamp01(viewVectorCoeff * 4.0);
	      viewVectorCoeff  = sqrt(viewVectorCoeff);
	
	normal.xy = diff * viewVectorCoeff;
	normal.z  = sqrt(1.0 - pow2(normal.x) - pow2(normal.y)); // Solve the equation "length(normal.xyz) = 1.0" for normal.z
	
	return normal;
}


vec3 GetNormal() {
	if (abs(materialIDs - 4.0) < 0.5)
		return normalize(GetWaveNormals(worldPosition.xyz) * tbnMatrix);
	else
		return normalize((texture2D(normals, texcoord).xyz * 2.0 - 1.0) * tbnMatrix);
}


void main() {
	if (CalculateFogFactor(viewSpacePosition, FOG_POWER) >= 1.0) discard;
	
	vec4 diffuse  = GetDiffuse();  if (diffuse.a < 0.1000003) discard; // Non-transparent surfaces will be invisible if their alpha is less than ~0.1000004. This basically throws out invisible leaf and tall grass fragments.
	vec3 normal   = GetNormal();
	
	#ifdef DEFERRED_SHADING
		gl_FragData[0] = vec4(diffuse.rgb, diffuse.a);
		gl_FragData[1] = vec4(vertLightmap.st, encodedMaterialIDs, 1.0);
		gl_FragData[2] = vec4(EncodeNormal(normal), 0.0, 1.0);
	#else
		Mask mask;
		CalculateMasks(mask, materialIDs, false);
		
		vec3 composite = CalculateShadedFragment(diffuse.rgb, mask, vertLightmap.r, vertLightmap.g, normal, viewSpacePosition);
		
		gl_FragData[0] = vec4(EncodeColor(composite), diffuse.a);
		gl_FragData[1] = vec4(vertLightmap.st, encodedMaterialIDs, 1.0);
		gl_FragData[2] = vec4(EncodeNormal(normal).xy, 0.0, 1.0);
		gl_FragData[3] = vec4(diffuse.rgb, 1.0);
	#endif
	
	exit();
}