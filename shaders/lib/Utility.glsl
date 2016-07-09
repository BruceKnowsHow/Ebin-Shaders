#define  PI 3.1415926 // Pi
#define RAD 0.0174533 // Degrees per radian

#define TIME frameTimeCounter

cvec3 lumaCoeff = vec3(0.2125, 0.7154, 0.0721);


#include "/lib/Utility/smoothing.glsl"

#include "/lib/Utility/lengthSquared.glsl"

#include "/lib/Utility/evenPowRootLength.glsl"

#include "/lib/Utility/clamping.glsl"

#include "/lib/Utility/encoding.glsl"

#include "/lib/Utility/rotation.glsl"

#include "/lib/Utility/blending.glsl"


vec3 SetSaturationLevel(in vec3 color, in float level) {
	float luminance = max(0.1175, dot(color, lumaCoeff));
	
	return mix(vec3(luminance), color, level);
}
