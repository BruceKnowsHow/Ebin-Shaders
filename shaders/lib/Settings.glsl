
// Start of #include "/lib/Settings.glsl"


const int   shadowMapResolution      = 2048;  // [1024 2048 3072 4096]
const float sunPathRotation          = 40.0;  // [-60.0 -50.0 -40.0 -30.0 -20.0 -10.0 0.0 10.0 20.0 30.0 40.0 50.0 60.0]
const float shadowDistance           = 140.0;
const float shadowIntervalSize       = 4.0;
const bool  shadowHardwareFiltering0 = true;

const int RGB8            = 0;
const int RGB16           = 0;
const int RGBA16          = 0;
const int colortex0Format = RGB16;
const int colortex2Format = RGB16;
const int colortex3Format = RGB8;
const int colortex4Format = RGBA16;
const int colortex5Format = RGB16;

const int   noiseTextureResolution = 64;
const float noiseTextureResolutionInverse = 1.0 / noiseTextureResolution;



#define EXPOSURE            1.0  // [0.2 0.4 0.6 0.8 1.0 2.0 4.0  8.0]
#define SUN_LIGHT_LEVEL     1.00 // [0.00 0.25 0.50 1.00 2.00 4.00 8.00 16.00]
#define SKY_LIGHT_LEVEL     1.00 // [0.00 0.25 0.50 1.00 2.00 4.00 8.00 16.00]
#define AMBIENT_LIGHT_LEVEL 1.00 // [0.00 0.25 0.50 1.00 2.00 4.00 8.00 16.00]
#define TORCH_LIGHT_LEVEL   1.00 // [0.00 0.25 0.50 1.00 2.00 4.00 8.00 16.00]
#define SKY_BRIGHTNESS      1.0  // [0.2 0.4 0.6 0.8 1.0 2.0 4.0 8.0]


#define BLOOM_AMOUNT        0.12 // [0.00 0.12 0.25 0.50 1.00]
#define BLOOM_CURVE         1.50 // [1.00 1.25 1.50 1.75 2.00]

//#define MOTION_BLUR
#define VARIABLE_MOTION_BLUR_SAMPLES
#define MAX_MOTION_BLUR_SAMPLE_COUNT            50    // [10 25 50 100]
#define VARIABLE_MOTION_BLUR_SAMPLE_COEFFICIENT 1.000 // [0.125 0.250 0.500 1.000]
#define CONSTANT_MOTION_BLUR_SAMPLE_COUNT       2     // [2 3 4 5 10]
#define MOTION_BLUR_INTENSITY                   1.0   // [0.5 1.0 2.0]
#define MAX_MOTION_BLUR_AMOUNT                  1.0   // [0.5 1.0 2.0]

//#define WAVING_GRASS
#define WAVING_LEAVES
#define WAVING_WATER

#define SHADOW_MAP_BIAS 0.80     // [0.00 0.60 0.70 0.80 0.85 0.90]
#define EXTENDED_SHADOW_DISTANCE
//#define SOFT_SHADOWS
#define PCSS
#define PLAYER_SHADOW

#define FOG_ENABLED
#define FOG_POWER 3.0                      // [1.0 2.0 3.0 4.0 6.0 8.0]
#define VOLUMETRIC_FOG_POWER 2.0           // [1.0 2.0 3.0 4.0]
#define ATMOSPHERIC_SCATTERING_AMOUNT 1.00 // [0.00 0.25 0.50 0.75 1.00 2.00 4.00]

#define GI_TRANSLUCENCE 0.2 // [0.0 0.2 0.4 0.6 0.8 1.0]
#define GI_RADIUS 16        // [4 8 16 24 32]
#define GI_QUALITY 1.00     // [0.25 0.50 1.00 2.00 3.00 4.00]
#define GI_BOOST


#define COMPOSITE0_SCALE 0.40 // [0.25 0.33 0.40 0.50 0.75 1.00]


#define REFLECTION_EDGE_FALLOFF

#define RECALCULATE_DISPLACED_NORMALS

//#define FORWARD_SHADING



/* Option unwravelling */
#ifdef GI_BOOST
	#define GI_Boost true
#else
	#define GI_Boost false
#endif

#ifdef FORWARD_SHADING
	#define Forward_Shading  true
	#define Deferred_Shading false
#else
	#define DEFERRED_SHADING
	#define Forward_Shading  false
	#define Deferred_Shading true
#endif

#ifdef FOG_ENABLED
	#define VOLUMETRIC_FOG
	#define Volumetric_Fog true
#else
	#define Volumetric_Fog false
#endif

#define PI 3.1415926
#define TIME frameTimeCounter

const bool biasShadowMap = (SHADOW_MAP_BIAS != 0.0);


// End of #include "/lib/Settings.glsl"
