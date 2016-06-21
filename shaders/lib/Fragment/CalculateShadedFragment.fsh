struct Shading {      // Contains scalar light levels without any color
	float normal;     // Coefficient of light intensity based on the dot product of the normal vector and the light vector
	float sunlight;
	float skylight;
	float caustics;
	float torchlight;
	float ambient;
};

struct Lightmap {    // Contains vector light levels with color
	vec3 sunlight;
	vec3 skylight;
	vec3 ambient;
	vec3 torchlight;
};


#include "/lib/Misc/BiasFunctions.glsl"
#include "/lib/Fragment/Sunlight/GetSunlightShading.fsh"

#if SHADOW_TYPE == 3 && defined composite1
	#include "/lib/Fragment/Sunlight/ComputeVariablySoftShadows.fsh"
#elif SHADOW_TYPE == 2 && defined composite1
	#include "/lib/Fragment/Sunlight/ComputeUniformlySoftShadows.fsh"
#else
	#include "/lib/Fragment/Sunlight/ComputeHardShadows.fsh"
#endif

#include "/lib/Fragment/Sunlight/CalculateDirectSunlight.fsh"


#if defined composite1
// Underwater light caustics
#endif


vec3 CalculateShadedFragment(in Mask mask, in float torchLightmap, in float skyLightmap, in vec3 normal, in float smoothness, in vec4 ViewSpacePosition) {
	Shading shading;
	
	shading.normal = GetOrenNayarShading(ViewSpacePosition, normal, 1.0 - smoothness, mask);
	
	shading.sunlight  = shading.normal;
	shading.sunlight *= pow2(skyLightmap);
	shading.sunlight  = CalculateDirectSunlight(ViewSpacePosition, shading.sunlight);
	
	#if defined composite1
		// Underwater light caustics
	#endif
	
	
	shading.torchlight = 1.0 - pow(clamp01(torchLightmap - 0.075), 4.0);
	shading.torchlight = 1.0 / pow(shading.torchlight, 2.0) - 1.0;
	
	shading.skylight = pow(skyLightmap, 4.0);
	
	shading.ambient = 1.0;
	
	
	Lightmap lightmap;
	
	lightmap.sunlight = shading.sunlight * sunlightColor;
	
	lightmap.skylight = shading.skylight * sqrt(skylightColor);
	
	lightmap.ambient = shading.ambient * vec3(1.0);
	
	lightmap.torchlight = shading.torchlight * vec3(0.7, 0.3, 0.1);
	
	
	return vec3(
	    lightmap.sunlight   * 6.0   * SUN_LIGHT_LEVEL
	+   lightmap.skylight   * 0.35  * SKY_LIGHT_LEVEL
	+   lightmap.ambient    * 0.015 * AMBIENT_LIGHT_LEVEL
	+   lightmap.torchlight * 3.0   * TORCH_LIGHT_LEVEL
	    );
}
