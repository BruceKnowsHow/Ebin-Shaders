#version 410 compatibility
#define gbuffers_textured_lit
#define fsh
#define ShaderStage -1
#include "/lib/Syntax.glsl"


/* DRAWBUFFERS:2305 */

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D noisetex;
uniform sampler2D shadowtex1;
uniform sampler2DShadow shadow;

uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;

uniform float frameTimeCounter;
uniform float far;
uniform float wetness;

uniform float viewWidth;
uniform float viewHeight;

varying mat4 shadowView;
#define shadowModelView shadowView

varying vec3 color;
varying vec2 texcoord;
varying vec2 lightmapCoord;

varying vec3 vertNormal;
varying mat3 tbnMatrix;
varying vec2 vertLightmap;

varying float mcID;
varying float materialIDs;
varying vec4  materialIDs1;

varying vec4 viewSpacePosition;
varying vec3 worldPosition;

#include "/lib/MenuInitializer.glsl"
#include "/lib/Settings.glsl"
#include "/lib/Util.glsl"
#include "/lib/DebugSetup.glsl"
#include "/lib/CalculateFogFactor.glsl"
#ifdef FORWARD_SHADING
#include "/lib/GlobalCompositeVariables.glsl"
#include "/lib/Masks.glsl"
#include "/lib/ShadingFunctions.fsh"
#endif


vec4 GetDiffuse() {
	vec4 diffuse = vec4(color.rgb, 1.0);
	     diffuse *= texture2D(texture, texcoord);
	
	return diffuse;
}

vec2 smoothNoiseCoord(in vec2 coord) { // Reduce bilinear artifacts by biasing the lookup coordinate towards the pixel center
	return floor(coord) + cubesmooth(fract(coord)) + 0.5;
}

float GetFractalWaveHeight(in vec2 coord, cvec2 wavelength, cvec2 speed, cvec2 direction, cfloat amplitude, inout float totalAmplitude) {
	cfloat angle = atan(normalize(direction).x, normalize(direction).y);
	
	coord += TIME * speed;
	rotate(coord, angle);
	coord /= wavelength;
	coord  = smoothNoiseCoord(coord);
	coord /= noiseTextureResolution;
	
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

vec4 GetNormal() {
	if (abs(materialIDs - 4.0) < 0.5)
		return vec4(normalize(GetWaveNormals(worldPosition.xyz) * tbnMatrix), 1.0);
	else {
		vec4 normal     = texture2D(normals, texcoord);
		     normal.xyz = normalize((normal.xyz * 2.0 - 1.0) * tbnMatrix);
		
		return normal;
	}
}

vec2 GetSpecularity(in float height, in float skyLightmap) {
	vec2 specular = texture2D(specular, texcoord).rg;
	
	float smoothness = specular.r;
	float metalness = specular.g;
	
	float wetfactor = wetness * pow(skyLightmap, 10.0);
	
	smoothness *= 1.0 + wetfactor;
	smoothness += (wetfactor - 0.5) * wetfactor;
	smoothness += (1 - height) * 0.5 * wetfactor;
	
	smoothness = clamp01(smoothness);
	
	return vec2(smoothness, metalness);
}

#include "/lib/Materials.glsl"


void main() {
	if (CalculateFogFactor(viewSpacePosition, FOG_POWER) >= 1.0) discard;
	
	vec4  diffuse            = GetDiffuse();    if (diffuse.a < 0.1000003) discard; // Non-transparent surfaces will be invisible if their alpha is less than ~0.1000004. This basically throws out invisible leaf and tall grass fragments.
	vec4  normal             = GetNormal();
	vec2  specularity        = GetSpecularity(normal.a, vertLightmap.t);
	float encodedMaterialIDs = EncodeMaterialIDs(materialIDs, specularity.g, materialIDs1.g, materialIDs1.b, materialIDs1.a);
	
	#ifdef DEFERRED_SHADING
		vec3 Colortex3 = vec3(Encode8to32(vertLightmap.s, vertLightmap.t, encodedMaterialIDs),
		                      Encode8to32(specularity.r, 0.0, 0.0), 0.0);
		
		gl_FragData[0] = vec4(pow(diffuse.rgb, vec3(2.2)) * 0.05, diffuse.a);
		gl_FragData[1] = vec4(Colortex3.rgb, 1.0);
		gl_FragData[2] = vec4(EncodeNormal(normal.xyz), 0.0, 1.0);
	#else
		Mask mask;
		CalculateMasks(mask, encodedMaterialIDs);
		
		float sunlight;
		
		vec3 composite = CalculateShadedFragment(pow(diffuse.rgb, vec3(2.2)), mask, vertLightmap.r, vertLightmap.g, normal.xyz, specularity.r, viewSpacePosition, sunlight);
		
		vec3 Colortex3 = vec3(Encode8to32(vertLightmap.s, vertLightmap.t, encodedMaterialIDs),
		                      Encode8to32(specularity.r, sunlight, 0.0), 0.0);
		
		gl_FragData[0] = vec4(EncodeColor(composite), diffuse.a);
		gl_FragData[1] = vec4(Colortex3.rgb, 1.0);
		gl_FragData[2] = vec4(EncodeNormal(normal.xyz).xy, 0.0, 1.0);
		gl_FragData[3] = vec4(diffuse.rgb, 1.0);
	#endif
	
	exit();
}
