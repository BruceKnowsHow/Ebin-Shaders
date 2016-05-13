
// Start of #include "/lib/CompositeCalculations.vsh"

// Prerequisites:
// 
// uniform vec3 sunPosition;
// uniform vec3 upPosition;
// 
// #include "/lib/Util.glsl"
// #include "/lib/GlobalCompositeVariables.glsl"


// {
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
// }


// End of #include "/lib/CompositeCalculations.vsh"
