/* DRAWBUFFERS:012345 */

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D noisetex;

uniform float frameTimeCounter;
uniform float far;
uniform float wetness;
uniform ivec2 atlasSize;

varying vec3 color;
varying vec2 texcoord;

varying mat3 tbnMatrix;
varying vec4 verts;
varying vec2 vertLightmap;

varying float mcID;
varying float materialIDs;

varying vec4 viewSpacePosition;
varying vec3 worldPosition;

varying vec3 worldNormal;
varying float tbnIndex;
varying float waterMask;

#include "/lib/Misc/Menu_Initializer.glsl"
#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"
#include "/lib/Debug.glsl"
#include "/lib/Misc/Calculate_Fogfactor.glsl"
#include "/lib/Fragment/Masks.fsh"

#if defined gbuffers_water
#include "/lib/Uniform/Global_Composite_Variables.glsl"
#include "/lib/Fragment/Calculate_Shaded_Fragment.fsh"
#endif

vec4 tileCoordinate(vec2 coord) {
	ivec2 atlasTiles = atlasSize / TEXTURE_PACK_RESOLUTION;
	vec2 tcoord = coord * atlasTiles;

	return vec4(fract(tcoord), floor(tcoord));
}

vec2 normalCoord(vec4 tileCoord) {
	ivec2 atlasTiles = atlasSize / TEXTURE_PACK_RESOLUTION;

	return (tileCoord.zw + fract(tileCoord.xy)) / atlasTiles;
}

vec2 getParallaxCoord(in vec2 coord, in vec3 direction, out float endHeight) {
	const vec3 stepSize = vec3(0.75, 0.75, 1.0) * 4.0 / TEXTURE_PACK_RESOLUTION;

	vec3 interval = direction * stepSize;

	vec4 tileCoord = tileCoordinate(coord);

	// Start state
	float foundHeight = textureLod(normals, coord, 0).a;
	vec3  offset = vec3(0.0, 0.0, 1.0);

	for(int i = 0; offset.z > foundHeight + 0.01 && i < 255; i++)
	{
		offset += mix(vec3(0.0), interval, pow(offset.z - foundHeight, 0.8));

		foundHeight = textureLod(normals, normalCoord(vec4(tileCoord.xy + offset.xy, tileCoord.zw)), 0).a;
	}

	endHeight = offset.z;

	tileCoord.xy += offset.xy;

	return normalCoord(tileCoord);
}


vec4 GetDiffuse(vec2 coord) {
	vec4 diffuse  = vec4(color.rgb, 1.0);
	     diffuse *= texture2D(texture, coord);
	
	return diffuse;
}

vec4 GetNormal(vec2 coord) {
#ifdef NORMAL_MAPS
	vec4 normal = texture2D(normals, coord);
#else
	vec4 normal = vec4(0.5, 0.5, 1.0, 1.0);
#endif
	
	normal.xyz = normalize(tbnMatrix * (normal.xyz * 2.0 - 1.0));
	
	return normal;
}

vec3 GetTangentNormal() {
#ifdef NORMAL_MAPS
	return texture2D(normals, texcoord).rgb;
#else
	return vec3(0.5, 0.5, 1.0);
#endif
}

float Get3DNoise(vec3 pos) {
	vec3 part  = floor(pos);
	vec3 whole = fract(pos);

	cvec2 zscale = vec2(17.0, 0.0);

	vec4 coord = part.xyxy + whole.xyxy + part.z * zscale.x + zscale.yyxx + 0.5;
	     coord /= noiseTextureResolution;

	float Noise1 = texture2D(noisetex, coord.xy).x;
	float Noise2 = texture2D(noisetex, coord.zw).x;

	return mix(Noise1, Noise2, whole.z);
}

float rainAlpha(float height, float skyLightmap) {
  float randWaterSpot  = Get3DNoise(worldPosition);
        randWaterSpot += Get3DNoise(worldPosition / 4.0) * 2.0;
        
  float heightOffset = max(0.25, (1.0 - height) * 0.2 + randWaterSpot * 0.8);
  
	float wetFactor = wetness * pow2(skyLightmap) * 2.0;
  float finalAlpha = clamp01(wetFactor - heightOffset);
  
  return clamp01(finalAlpha);
}

vec2 GetSpecularity(vec2 coord, float finalAlpha, float skyLightmap) {
#ifdef SPECULARITY_MAPS
	vec2 specular = texture2D(specular, coord).rg;
	
	float smoothness = specular.r;
	float F0 = specular.g;
	
	smoothness = mix(smoothness, 0.98, finalAlpha);
  
	return vec2(smoothness, F0);
#else
	return vec2(0.0);
#endif
}

vec2 EncodeNormalData(vec3 normalTexture, float tbnIndex) {
	vec2 encode;
	
	encode.r = (tbnIndex + 8.0 * waterMask) / 16.0;
	encode.g = Encode16(normalTexture.xy);
	
	return encode;
}


void main() {
	if (CalculateFogFactor(viewSpacePosition, FOG_POWER) >= 1.0) discard;
	
	vec3 tangentVector = normalize(tbnMatrix * normalize(viewSpacePosition.xyz));
	float textureHeight;
	
	vec2 coord = texcoord;
	
	if(length(viewSpacePosition.xyz) < 30.0)
		coord = getParallaxCoord(texcoord, tangentVector, textureHeight);
  
	vec4 diffuse = GetDiffuse(coord);
	if (diffuse.a < 0.1000003) discard;
	
	vec4 normal = GetNormal(coord);
	
  float wetnessAlpha = rainAlpha(normal.a, vertLightmap.t);
	
  diffuse = mix(diffuse, diffuse * vec4(1.0, 0.970588, 0.8745098, 1.0) * 0.74, wetnessAlpha);
	normal = mix(normal, vec4(normalize(tbnMatrix * (vec3(0.5, 0.5, 1.0) * 2.0 - 1.0)), 1.0), wetnessAlpha * worldNormal.y);
	
	vec2 specularity = GetSpecularity(coord, wetnessAlpha, vertLightmap.t);	
	
	
#if !defined gbuffers_water
	float encodedMaterialIDs = EncodeMaterialIDs(materialIDs, specularity.g, 0.0, 0.0, 0.0);
	
	vec2 encode = vec2(Encode16(vec2(specularity.r, vertLightmap.g)), Encode16(vec2(vertLightmap.r, encodedMaterialIDs)));
	
	gl_FragData[0] = vec4(0.0, 0.0, 0.0, 1.0);
	gl_FragData[1] = vec4(diffuse.rgb, 1.0);
	gl_FragData[2] = vec4(0.0);
	gl_FragData[3] = vec4(0.0);
	gl_FragData[4] = vec4(EncodeNormal(normal.xyz), encode.r, 1.0);
	gl_FragData[5] = vec4(encode.g, 0.0, 0.0, 1.0);
#else
	float encode = Encode16(vec2(specularity.r, vertLightmap.g));
	
	vec2 encodedNormal = EncodeNormalData(GetTangentNormal(), tbnIndex);
	
	Mask mask;
	
	if (abs(mcID - 8.5) < 0.6) diffuse.a = 0.5; // Force water alpha
	
	vec3 composite  = CalculateShadedFragment(mask, vertLightmap.r, vertLightmap.g, vec3(0.0), 1.0, normal.xyz, specularity.r, viewSpacePosition);
	     composite *= pow(diffuse.rgb, vec3(2.2));
	
	gl_FragData[0] = vec4(encodedNormal, encode, 1.0);
	gl_FragData[1] = vec4(0.0);
	gl_FragData[2] = vec4(1.0, 0.0, 0.0, diffuse.a);
	gl_FragData[3] = vec4(composite, diffuse.a);
#endif
	
	exit();
}
