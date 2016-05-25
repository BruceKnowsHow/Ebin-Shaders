
// Start of #include "/lib/CompositeCalculations.vsh"

/* Prerequisites:

uniform mat4 gbufferModelView;

uniform vec3 upPosition;

// #include "/lib/Util.glsl"
// #include "/lib/ShadowViewMatrix.vsh"
// #include "/lib/GlobalCompositeVariables.glsl"

*/


// {
	float isNight = CalculateShadowView();
	
	vec3 sunVector = normalize((gbufferModelView * shadowViewInverse * vec4(0.0, 0.0, 1.0, 0.0)).xyz);
	
	lightVector = sunVector;
	
	sunVector *= 1.0 - isNight * 2.0;
	
	float LdotUp = dot(sunVector, normalize(upPosition));
	
	const float timePower = 4.0;
	
//	horizonTime = cubesmooth(clamp01((1.0 - abs(LdotUp)) * 4.0 - 3.0));
	
	timeDay   = 1.0 - pow(1.0 - clamp01( LdotUp - 0.1) / 0.9, timePower);
	timeNight = 1.0 - pow(1.0 - clamp01(-LdotUp), timePower);
	
	timeHorizon	= (1.0 - timeDay) * (1.0 - timeNight);// clamp01(1.0 - timeDay - timeNight);
	
	/*
	timeDay      = sin( LdotUp * PI * 0.5);
	timeNight    = sin(-LdotUp * PI * 0.5);
	timeHorizon  = pow(1 + timeDay * timeNight, 4.0);
	
	float horizonClip = max0(0.9 - timeHorizon) / 0.9;
	
	timeDay = clamp01(timeDay * horizonClip);
	timeNight = clamp01(timeNight * horizonClip);
	*/
	
	float timeSunrise  = timeHorizon * timeDay;
	float timeMoonrise = timeHorizon * timeNight;
	
	
	#include "/lib/Colors.glsl"
	
	
	sunlightColor =
		mix(sunlightDay  , sunlightSunrise , timeHorizon  ) * timeDay +
		mix(sunlightNight, sunlightMoonrise, timeMoonrise * timeNight) * timeNight;
	
	skylightColor =
		mix(skylightDay, skylightSunrise, timeHorizon * timeDay) * timeDay +
		skylightNight * timeNight + skylightHorizon * timeHorizon;
	
	
//	skyMainColor = skylightColor;
//	horizonColor = skylightColor;
//	sunGlowColor = skylightColor;
// }


// End of #include "/lib/CompositeCalculations.vsh"
