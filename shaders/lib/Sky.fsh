
// Start of #include "/lib/Sky.fsh"

/* Prerequisites:

uniform mat4 gbufferModelViewInverse;

uniform float far;

varying vec3 lightVector;

// #include "/lib/Settings.glsl"
// #include "/lib/Util.glsl"
// #include "/lib/GlobalCompositeVariables.glsl"
// #include "/lib/CalculateFogFactor.glsl"

*/


float CalculateSunlow(in vec4 viewSpacePosition) {
	float sunglow = max0(dot(normalize(viewSpacePosition.xyz), lightVector) - 0.01);
	      sunglow = pow(sunglow, 8.0) * 5.0;
	
	return sunglow;
}


vec3 CalculateSkyGradient(in vec4 viewSpacePosition) {
	float radius = max(176.0, far * sqrt(2.0));
	
	vec3 worldPosition = (gbufferModelViewInverse * vec4(normalize(viewSpacePosition.xyz), 0.0)).xyz;
	
#ifdef CUSTOM_HORIZON_HEIGHT
	worldPosition.y  = radius * worldPosition.y / length(worldPosition.xz) + cameraPosition.y - HORIZON_HEIGHT; // Reproject the world vector to have a consistent horizon height
	worldPosition.xz = normalize(worldPosition.xz) * radius;
#endif
	
	float dotUP = dot(normalize(worldPosition), vec3(0.0, 1.0, 0.0));
	
	float horizonCoeff = dotUP * 0.65;
	      horizonCoeff = abs(horizonCoeff);
	      horizonCoeff = pow(1.0 - horizonCoeff, 4.0) / 0.65 * 5.0;
	
	float sunglow = CalculateSunlow(viewSpacePosition);
	
	vec3 color  = horizonCoeff * pow(colorSkylight, vec3((10.0 - horizonCoeff) / 5.5)); // Sky desaturates as it approaches the horizon
	     color += sunglow * pow(colorSkylight, vec3(1.3));
	
	return color;
}

vec3 CalculateSunspot(in vec4 viewSpacePosition) {
	float sunspot  = max0(dot(normalize(viewSpacePosition.xyz), lightVector) - 0.01);
	      sunspot  = pow(sunspot, 350.0);
	      sunspot  = pow(sunspot + 1.0, 400.0) - 1.0;
	      sunspot  = min(sunspot, 20.0);
	      sunspot += 100.0 * float(sunspot == 20.0);
	
	return sunspot * colorSunlight * colorSunlight;
}

vec3 CalculateAtmosphereScattering(in vec4 viewSpacePosition) {
	float factor = pow(length(viewSpacePosition.xyz), 1.4) * 0.0001 * ATMOSPHERIC_SCATTERING_AMOUNT;
	
	return pow(colorSkylight, vec3(3.5)) * factor;
}

void CompositeFog(inout vec3 color, in vec4 viewSpacePosition, in float fogVolume) {
	#ifndef FOG_ENABLED
	color += CalculateAtmosphereScattering(viewSpacePosition);
	#else
	
	vec3 atmosphere = CalculateAtmosphereScattering(viewSpacePosition);
	color += atmosphere * SKY_BRIGHTNESS;
	
	
	vec4 skyComposite;
	float fogFactor = CalculateFogFactor(viewSpacePosition, FOG_POWER);
	skyComposite.a  = GetSkyAlpha(fogVolume, fogFactor);
	if (skyComposite.a < 0.0001) return;
	
	
	if (isEyeInWater == 1) {
		color = mix(color, vec3(0.0, 0.01, 0.1) * colorSkylight, skyComposite.a); return; }
	
	
	vec3 gradient = CalculateSkyGradient(viewSpacePosition);
	vec3 sunspot  = CalculateSunspot(viewSpacePosition) * pow(fogFactor, 25);
	
	skyComposite.rgb = (gradient + sunspot) * SKY_BRIGHTNESS;
	
	color = mix(color, skyComposite.rgb, skyComposite.a);
	#endif
}

vec3 CalculateSky(in vec4 viewSpacePosition, const bool sunSpot) {
	if (isEyeInWater == 1) return vec3(0.0, 0.01, 0.1) * colorSkylight; // waterVolumeColor from composite1
	
	viewSpacePosition.xyz = normalize(viewSpacePosition.xyz);
	
	vec3 gradient   = CalculateSkyGradient(viewSpacePosition);
	vec3 sunspot    = (sunSpot ? CalculateSunspot(viewSpacePosition) : vec3(0.0));
	vec3 atmosphere = CalculateAtmosphereScattering(viewSpacePosition);
	
	return (gradient + sunspot + atmosphere) * SKY_BRIGHTNESS;
}

vec3 CalculateReflectedSky(in vec4 viewSpacePosition) {
	if (isEyeInWater == 1) return vec3(0.0, 0.01, 0.1) * colorSkylight;
	
	viewSpacePosition.xyz = normalize(viewSpacePosition.xyz);
	
	vec3 gradient   = CalculateSkyGradient(viewSpacePosition);
	vec3 atmosphere = CalculateAtmosphereScattering(viewSpacePosition);
	
	return (gradient + atmosphere) * SKY_BRIGHTNESS;
}


// End of #include "/lib/Sky.fsh"
