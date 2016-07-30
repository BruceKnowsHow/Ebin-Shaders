float CalculateSunglow(in vec4 viewSpacePosition) {
	float sunglow = max0(dot(normalize(viewSpacePosition.xyz), lightVector) - 0.01);
	      sunglow = pow(sunglow, 8.0);
	
	return sunglow;
}

vec3 CalculateSkyGradient(in vec4 viewSpacePosition, in float fogFactor) {
	float radius = max(176.0, far * sqrt(2.0));
	
	vec4 worldPosition = gbufferModelViewInverse * vec4(normalize(viewSpacePosition.xyz), 0.0);
	
#ifdef CUSTOM_HORIZON_HEIGHT
	worldPosition.y  = radius * worldPosition.y / length(worldPosition.xz) + cameraPosition.y - HORIZON_HEIGHT; // Reproject the world vector to have a consistent horizon height
	worldPosition.xz = normalize(worldPosition.xz) * radius;
#endif
	
	float dotUP = dot(normalize(worldPosition.xyz), vec3(0.0, 1.0, 0.0));
	
	
	float gradientCoeff = pow(1.0 - abs(dotUP) * 0.5, 4.0);
	
	float sunglow = CalculateSunglow(viewSpacePosition);
	
	
	vec3 primaryHorizonColor  = SetSaturationLevel(skylightColor, mix(1.0, 0.5, gradientCoeff * timeDay));
	     primaryHorizonColor  = SetSaturationLevel(primaryHorizonColor, mix(1.0, 1.1, timeDay));
	     primaryHorizonColor *= (1.0 + gradientCoeff * 0.5);
	     primaryHorizonColor  = mix(primaryHorizonColor, sunlightColor, gradientCoeff * sunglow * timeDay);
	
	vec3 sunglowColor = mix(skylightColor, sunlightColor * 0.5, gradientCoeff * sunglow) * sunglow;
	
	
	vec3 color  = primaryHorizonColor * gradientCoeff * 8.0; // Sky desaturates as it approaches the horizon
	     color *= 1.0 + sunglowColor * 2.0;
	     color += sunglowColor * 5.0;
	
	return color * 0.9;
}

vec3 CalculateSunspot(in vec4 viewSpacePosition) {
	float sunspot  = max0(dot(normalize(viewSpacePosition.xyz), lightVector) - 0.01);
	      sunspot  = pow(sunspot, 350.0);
	      sunspot  = pow(sunspot + 1.0, 400.0) - 1.0;
	      sunspot  = min(sunspot, 20.0);
	      sunspot += 100.0 * float(sunspot == 20.0);
	
	return sunspot * sunlightColor * sunlightColor * vec3(1.0, 0.8, 0.6);
}

vec3 CalculateAtmosphereScattering(in vec4 viewSpacePosition) {
	float factor = pow(length(viewSpacePosition.xyz), 1.4) * 0.0001 * ATMOSPHERIC_SCATTERING_AMOUNT;
	
	return pow(skylightColor, vec3(2.5)) * factor;
}

#include "/lib/Fragment/Clouds.fsh"

#include "/lib/Fragment/Atmosphere.fsh"

vec3 CalculateAtmosphericSky(in vec4 viewSpacePosition) {
	vec3 playerSpacePosition = (gbufferModelViewInverse * vec4(viewSpacePosition.xyz, 0.0)).xyz;
	vec3 worldLightVector    = (gbufferModelViewInverse * vec4(lightVector, 0.0)).xyz;
	vec3 worldPosition       = vec3(0.0, planetRadius + 1.061e3 / ebin + max0(cameraPosition.y - HORIZON_HEIGHT) * 400.0 / ebin, 0.0);
	
	return ComputeAtmosphericSky(playerSpacePosition, worldPosition, worldLightVector, 1.0);
	
	return vec3(0.0);
}

vec3 CalculateSky(in vec4 viewSpacePosition, in float alpha, cbool reflection) {
	float visibility = CalculateFogFactor(viewSpacePosition, FOG_POWER);
	
	if (visibility < 0.001 && !reflection) return vec3(0.0);
	
	return CalculateAtmosphericSky(viewSpacePosition);
	
	vec3 gradient = CalculateSkyGradient(viewSpacePosition, visibility);
	vec3 sunspot  = reflection ? vec3(0.0) : CalculateSunspot(viewSpacePosition) * pow(visibility, 25) * alpha;
	vec3 clouds   = swizzle.ggg;
	
	return (gradient + sunspot + clouds) * SKY_BRIGHTNESS;
}
