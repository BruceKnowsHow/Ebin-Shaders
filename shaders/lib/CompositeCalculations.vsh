// Start of #include "/lib/CompositeCalculations.vsh"

/* Prerequisites:

uniform mat4 gbufferModelView;

uniform vec3 upPosition;

// #include "/lib/Utility.glsl"
// #include "/lib/ShadowViewMatrix.vsh"
// #include "/lib/GlobalCompositeVariables.glsl"

*/

// {
	float isNight = CalculateShadowView();
	
	vec3 sunVector = normalize((gbufferModelView * shadowViewInverse * vec4(0.0, 0.0, 1.0, 0.0)).xyz);
	
	lightVector = sunVector;
	
	sunVector *= 1.0 - isNight * 2.0;
	
	float LdotUp = dot(sunVector, normalize(upPosition));
	
	cfloat timePower = 4.0;
	
	timeDay   = 1.0 - pow(1.0 - clamp01( LdotUp - 0.1) / 0.9, timePower);
	timeNight = 1.0 - pow(1.0 - clamp01(-LdotUp), timePower);
	
	timeHorizon	= (1.0 - timeDay) * (1.0 - timeNight);
	
	
	float timeSunrise  = timeHorizon * timeDay;
	float timeMoonrise = timeHorizon * timeNight;
	
	
	#include "/lib/Colors.glsl"
	
	
	sunlightColor =
		mix(sunlightDay  , sunlightSunrise , timeHorizon) * timeDay +
		mix(sunlightNight, sunlightMoonrise, timeMoonrise * timeNight) * timeNight;
	
	skylightColor =
		mix(skylightDay, skylightSunrise, timeHorizon) * timeDay +
		skylightNight * timeNight + skylightHorizon * timeHorizon;
// }

// End of #include "/lib/CompositeCalculations.vsh"