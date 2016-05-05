#version 120
//#define COMPOSITE0_VERTEX
#define COMPOSITE2_VERTEX

#define COMPOSITE0_SCALE 0.40

uniform float viewWidth;
uniform float viewHeight;

varying vec2 texcoord;

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

#define PI 3.14159
//#include include/PostHeader.vsh"


void main() {
	texcoord    = gl_MultiTexCoord0.st;
	gl_Position = ftransform();
	
	#ifdef COMPOSITE0_VERTEX
		gl_Position.xy = ((gl_Position.xy * 0.5 + 0.5) * COMPOSITE0_SCALE) * 2.0 - 1.0;
	#endif
	
	#ifdef COMPOSITE2_VERTEX
		vec2 pixelSize = 1.0 / vec2(viewWidth, viewHeight);
		
		#define COMPOSITE2_SCALE vec2(0.25 + pixelSize.x * 2.0, 0.375 + pixelSize.y * 4.0)
		
		gl_Position.xy = ((gl_Position.xy * 0.5 + 0.5) * COMPOSITE2_SCALE) * 2.0 - 1.0;    // Crop the vertex to only cover the areas that are being used
		
		texcoord *= COMPOSITE2_SCALE;    // Compensate for the vertex adjustment to make this a true "crop" rather than a "downscale"
	#endif
	
	
//#include "include/PostCalculations.vsh"
	vec3 sunVector = normalize(sunPosition); //Engine-time overrides will happen by modifying sunVector
	
	lightVector = sunVector * mix(1.0, -1.0, float(dot(sunVector, upPosition) < 0.0));
	
	
	float sunUp   = dot(sunVector, normalize(upPosition));
	
	timeDay      = sin( sunUp * PI * 0.5);
	timeNight    = sin(-sunUp * PI * 0.5);
	timeHorizon  = pow(1 + timeDay * timeNight, 4.0);
	
	float horizonClip = max(0.0, 0.9 - timeHorizon) / 0.9;
	
	timeDay = clamp01(timeDay * horizonClip);
	timeNight = clamp01(timeNight * horizonClip);
	
	float timeSunrise  = timeHorizon * timeDay;
	float timeMoonrise = timeHorizon * timeNight;
	
	vec3 sunlightDay =
	vec3(1.0, 1.0, 1.0);
	
	vec3 sunlightNight =
	vec3(0.43, 0.65, 1.0) * 0.025;
	
	vec3 sunlightSunrise =
	vec3(1.00, 0.50, 0.00);
	
	vec3 sunlightMoonrise =
	vec3(0.90, 1.00, 1.00);
	
	colorSunlight  = sunlightDay * timeDay + sunlightNight * timeNight + sunlightSunrise * timeSunrise + sunlightMoonrise * timeMoonrise;
	
	
	const vec3 skylightDay =
	vec3(0.24, 0.58, 1.00);
	
	const vec3 skylightNight =
	vec3(0.25, 0.5, 1.0) * 0.025;
	
	const vec3 skylightHorizon =
	vec3(0.29, 0.48, 1.0) * 0.01;
	
	colorSkylight = skylightDay * timeDay + skylightNight * timeNight + skylightHorizon * timeHorizon;
//#include "include/PostCalculations.vsh"
}