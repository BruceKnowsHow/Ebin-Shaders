#version 120

/* DRAWBUFFERS:2306 */

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D noisetex;

uniform sampler2DShadow shadow;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelViewInverse;

uniform float frameTimeCounter;
uniform float far;

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
#ifdef FORWARD_SHADING
#include "/lib/Masks.glsl"
#include "/lib/ShadingFunctions.fsh"
#endif


vec3 DecodeColor(in vec3 color) {
	return pow(color, vec3(2.2)) * 1000.0;
}

vec3 EncodeColor(in vec3 color) {    // Prepares the color to be sent through a limited dynamic range pipeline
	return pow(color * 0.001, vec3(1.0 / 2.2));
}

vec4 GetDiffuse() {
	vec4 diffuse = vec4(color.rgb, 1.0);
	     diffuse *= texture2D(texture, texcoord);
	
	return diffuse;
}

vec2 EncodeNormal(vec3 normal) {
    float p = sqrt(normal.z * 8.0 + 8.0);
    return vec2(normal.xy / p + 0.5) * 0.5 + 0.5;
}

float GetWaveDifferential(in vec2 pos, in float wavelength, in float amplitude, in float speed, in vec2 direction) {
	return wavelength * amplitude * (cos(dot(pos, direction) * wavelength + TIME * speed));
}

void GetWaveVectors(inout vec3 normal, in vec2 pos, in float wavelength, in float amplitude, in float speed, in vec2 direction) {
	direction  = normalize(direction);
	wavelength = 1.0 / wavelength * PI * 2.0;
	
	amplitude *= 0.1;
	
	float wave = GetWaveDifferential(pos, wavelength, amplitude, speed, direction);
	
	normal.x += direction.x * wave;
	normal.y += direction.y * wave;
}

vec3 GetWaves(in vec3 position) {
	vec3 normal = vec3(0.0, 0.0, 0.0);
	
	GetWaveVectors(normal, position.xz, 1.0 ,  0.01, 2.0, vec2( 0.4 , 0.8 ));
	GetWaveVectors(normal, position.xz, 5.0 ,  0.01, 3.0, vec2( 0.3 , 0.1 ));
	GetWaveVectors(normal, position.xz, 1.0 ,  0.01, 5.0, vec2( 0.25, 0.16));
	GetWaveVectors(normal, position.xz, 2.0 ,  0.02, 4.0, vec2(-0.8 , 0.56));
	GetWaveVectors(normal, position.xz, 3.5 , 0.005, 2.1, vec2(-1.0 , 0.1 ));
	GetWaveVectors(normal, position.xz, 0.79, 0.003, 2.5, vec2( 1.6 , 0.1 ));
	GetWaveVectors(normal, position.xz, 1.4 , 0.015, 1.5, vec2( 0.6 ,-0.5 ));
	
	normal.z = sqrt(1.0 - pow2(normal.x) - pow2(normal.y));    // Solve the equation "length(normal.xyz) = 1.0" for normal.z
	
	return normal;
}

vec3 GetNormal() {
	if (abs(materialIDs - 4.0) < 0.5)
		return normalize(GetWaves(worldPosition.xyz) * tbnMatrix);
	else
		return normalize((texture2D(normals, texcoord).xyz * 2.0 - 1.0) * tbnMatrix);
}


void main() {
	if (CalculateFogFactor(viewSpacePosition.xyz, FOG_POWER) >= 1.0) discard;
	
	vec4 diffuse  = GetDiffuse();  if (diffuse.a < 0.1000003) discard;    // Non-transparent surfaces will be invisible if their alpha is less than ~0.1000004. This basically throws out invisible leaf and tall grass fragments.
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
}