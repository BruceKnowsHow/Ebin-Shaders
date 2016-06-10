// Start of #include "/lib/Settings.glsl"

const int   shadowMapResolution      = 2048;  // [1024 2048 3072 4096]
const float sunPathRotation          = -40.0;  // [-60.0 -50.0 -40.0 -30.0 -20.0 -10.0 0.0 10.0 20.0 30.0 40.0 50.0 60.0]
const float shadowDistance           = 140.0;
const float shadowIntervalSize       = 40.0;
const bool  shadowHardwareFiltering0 = true;

const float wetnessHalflife          = 200.0;
const float drynessHalflife          = 40.0;

/*
const int colortex0Format = RG16;
const int colortex1Format = RGB16;
const int colortex2Format = RGB16;
const int colortex3Format = RG16;
const int colortex4Format = RGBA8;
const int colortex5Format = RGB8;
const int colortex6Format = R8;
*/

const int noiseTextureResolution = 64;



// GUI Settings
//#define DEFAULT_TEXTURE_PACK


#define EXPOSURE            1.0  // [0.2 0.4 0.6 0.8 1.0 2.0 4.0  8.0]
#define SATURATION          1.15 // [0.00 0.50 1.00 1.15 1.30]
#define SUN_LIGHT_LEVEL     1.00 // [0.00 0.25 0.50 1.00 2.00 4.00 8.00 16.00]
#define SKY_LIGHT_LEVEL     1.00 // [0.00 0.25 0.50 1.00 2.00 4.00 8.00 16.00]
#define AMBIENT_LIGHT_LEVEL 1.00 // [0.00 0.25 0.50 1.00 2.00 4.00 8.00 16.00]
#define TORCH_LIGHT_LEVEL   1.00 // [0.00 0.25 0.50 1.00 2.00 4.00 8.00 16.00]
#define SKY_BRIGHTNESS      1.0  // [0.2 0.4 0.6 0.8 1.0 2.0 4.0 8.0]


#define BLOOM_ENABLED
#define BLOOM_AMOUNT        0.12 // [0.05 0.12 0.25 0.50 1.00]
#define BLOOM_CURVE         1.50 // [1.00 1.25 1.50 1.75 2.00]

//#define MOTION_BLUR
#define VARIABLE_MOTION_BLUR_SAMPLES
#define MAX_MOTION_BLUR_SAMPLE_COUNT            50    // [10 25 50 100]
#define VARIABLE_MOTION_BLUR_SAMPLE_COEFFICIENT 1.000 // [0.125 0.250 0.500 1.000]
#define CONSTANT_MOTION_BLUR_SAMPLE_COUNT       2     // [2 3 4 5 10]
#define MOTION_BLUR_INTENSITY                   1.0   // [0.5 1.0 2.0]
#define MAX_MOTION_BLUR_AMOUNT                  1.0   // [0.5 1.0 2.0]

#define WAVING_GRASS
#define WAVING_LEAVES
#define WAVING_WATER

#define SHADOW_MAP_BIAS 0.80     // [0.00 0.60 0.70 0.80 0.85 0.90]
#define EXTENDED_SHADOW_DISTANCE
#define SHADOW_TYPE 2 // [1 2 3]
#define PLAYER_SHADOW

#define FOG_ENABLED
#define FOG_POWER 3.0                      // [1.0 2.0 3.0 4.0 6.0 8.0]
#define VOLUMETRIC_FOG_POWER 2.0           // [1.0 2.0 3.0 4.0]
#define ATMOSPHERIC_SCATTERING_AMOUNT 1.00 // [0.00 0.25 0.50 0.75 1.00 2.00 4.00]

#define GI_ENABLED
#define GI_MODE         1    // [1 2]
#define GI_RADIUS       16   // [4 8 16 24 32]
#define GI_SAMPLE_COUNT 80   // [20 40 80 128 160 256]
#define GI_BOOST
#define GI_TRANSLUCENCE 0.2  // [0.0 0.2 0.4 0.6 0.8 1.0]
#define GI_BRIGHTNESS   1.00 // [0.25 0.50 0.75 1.00 2.00 4.00]


#define COMPOSITE0_SCALE 0.40 // [0.25 0.33 0.40 0.50 0.75 1.00]


#define REFLECTION_EDGE_FALLOFF

#define WAVE_MULT 1.3


#define FRESNEL 3 // [1 2 3]
#define PBR_SKEW 3 // [1 2 3]
#define PBR_RAYS 2 // [1 2 4 6 8 16 32]
#define PBR_GEOMETRY_MODEL 5 // [1 2 3 4 5 6]
#define PBR_DISTROBUTION_MODEL 3 // [1 2 3]

#define RECALCULATE_DISPLACED_NORMALS

#define CUSTOM_HORIZON_HEIGHT
#define HORIZON_HEIGHT 62 // [5 62 72 80 128 192 208]

//#define FORWARD_SHADING


#define DEBUG_VIEW 1 // [-1 0 1 2 3 7]


// Option unwravelling
#ifdef GI_BOOST
	#define GI_Boost true
#else
	#define GI_Boost false
#endif

#ifdef FORWARD_SHADING
	#define Forward_Shading  true
	#define Deferred_Shading false
#else
	#define Forward_Shading  false
	#define Deferred_Shading true
#endif

#ifdef FOG_ENABLED
	#define VOLUMETRIC_FOG
	#define Volumetric_Fog true
#else
	#define Volumetric_Fog false
#endif

#ifdef DEFAULT_TEXTURE_PACK
	#define TEXTURE_PACK_RESOLUTION 16
#else
	#define TEXTURE_PACK_RESOLUTION_SETTING 128 // [16 32 64 128 256 512]
	
	#define TEXTURE_PACK_RESOLUTION TEXTURE_PACK_RESOLUTION_SETTING
	
	#define NORMAL_MAPS
	
	#define SPECULARITY_MAPS
	//#define PBR_TEXTURE_PACK
	
	#ifdef PBR_TEXTURE_PACK
		#define PBR
	#endif
#endif
/*
#ifdef NORMAL_MAPS
#ifdef SPECULARITY_MAPS
*/
cbool biasShadowMap = (SHADOW_MAP_BIAS != 0.0);

// End of #include "/lib/Settings.glsl"