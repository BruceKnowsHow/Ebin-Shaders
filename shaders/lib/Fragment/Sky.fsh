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


const vec3  rayleighScattering = vec3(5.5e-6, 13.0e-6, 22.4e-6);
const float rayleighHeight     = 8.0e3;

const float     planetRadius = 6371.0;
const float atmosphereRadius = 6471.0;

const float     planetSquared =     planetRadius * planetRadius;
const float atmosphereSquared = atmosphereRadius * atmosphereRadius;


float AtmosphereLength(in vec3 worldVector, in vec3 worldDirection) {
	return 0.0;
}

#define iSteps 1
#define jSteps 1

#define R_OUTER 647
#define R_INNER 637

float rsi(vec3 r0, vec3 rd) {
	// Simplified ray-sphere intersection that assumes
	// the ray starts inside the sphere and that the
	// sphere is centered at the origin. Always intersects.
	float a = dot(rd, rd);
	float b = 2.0 * dot(rd, r0);
	float c = dot(r0, r0) - (R_OUTER * R_OUTER);
	float d = (-b + sqrt((b*b) - 4.0*a*c))/(2.0*a);
	
	return d;
}

vec3 atmosphere(vec3 r, vec3 r0, vec3 pSun, float iSun, vec3 kRlh, float shRlh) {
	// Normalize the sun and view directions.
	pSun = normalize(pSun);
	r = normalize(r);
	
	// Calculate the step size of the primary ray.
	float iStepSize = rsi(r0, r) / float(iSteps);
	
	// Initialize the primary ray time.
	float iTime = 0.0;
	
	// Initialize accumulators for Rayleigh and Mie scattering.
	vec3 totalRlh = vec3(0,0,0);
	
	// Initialize optical depth accumulators for the primary ray.
	float iOdRlh = 0.0;
	
	// Calculate the Rayleigh and Mie phases.
	float mu = dot(r, pSun);
	float mumu = mu * mu;
	float pRlh = 3.0 / (16.0 * PI) * (1.0 + mumu);
	
	// Sample the primary ray.
	for (int i = 0; i < iSteps; i++) {
		
		// Calculate the primary ray sample position.
		vec3 iPos = r0 + r * (iTime + iStepSize * 0.5);
		
		// Calculate the height of the sample.
		float iHeight = length(iPos) - R_INNER;
		
		// Calculate the optical depth of the Rayleigh and Mie scattering for this step.
		float odStepRlh = exp(-iHeight / shRlh) * iStepSize;
		
		// Accumulate optical depth.
		iOdRlh += odStepRlh;
		
		// Calculate the step size of the secondary ray.
		float jStepSize = rsi(iPos, pSun) / float(jSteps);
		
		// Initialize the secondary ray time.
		float jTime = 0.0;
		
		// Initialize optical depth accumulators for the secondary ray.
		float jOdRlh = 0.0;
		
		// Sample the secondary ray.
		for (int j = 0; j < jSteps; j++) {
			
			// Calculate the secondary ray sample position.
			vec3 jPos = iPos + pSun * (jTime + jStepSize * 0.5);
			
			// Calculate the height of the sample.
			float jHeight = length(jPos) - R_INNER;
			
			// Accumulate the optical depth.
			jOdRlh += exp(-jHeight / shRlh) * jStepSize;
			
			// Increment the secondary ray time.
			jTime += jStepSize;
		}
		
		// Calculate attenuation.
		vec3 attn = exp(-(kRlh * (iOdRlh + jOdRlh)));
		
		// Accumulate scattering.
		totalRlh += odStepRlh * attn;
		
		// Increment the primary ray time.
		iTime += iStepSize;
    }
	
	// Calculate and return the final color.
	
	vec3 color = iSun * pRlh * kRlh * totalRlh;
	
	if (any(isnan(color))) color = vec3(0.0);
	
	return color;
}

vec3 CalculateAtmosphericSky(in vec4 viewSpacePosition, in float fogFactor) {
	vec3 worldSpacePosition = (gbufferModelViewInverse * viewSpacePosition).xyz;
	vec3 worldLightVector   = (gbufferModelViewInverse * vec4(lightVector, 0.0)).xyz;
	vec3 r0                 = vec3(0.0, planetRadius + (cameraPosition.y - 120.0), 0.0);
	
//	show(AtmosphereLength(r0, normalize(worldSpacePosition)));
	
	/*
	return atmosphere(
		worldSpacePosition,             // normalized ray direction
		r0,                             // ray origin
		worldLightVector,               // position of the sun
		100.0,                           // intensity of the sun
		vec3(2.5e-2, 10.0e-2, 22.4e-2), // Rayleigh scattering coefficient
		1.0                           // Rayleigh scale height
	); */
	
	return vec3(0.0);
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

vec3 CalculateSky(in vec4 viewSpacePosition, in float alpha, cbool reflection) {
	float visibility = CalculateFogFactor(viewSpacePosition, FOG_POWER);
	
//	if (visibility < 0.001 && !reflection) return vec3(0.0);
	
	
	vec3 gradient = CalculateSkyGradient(viewSpacePosition, visibility);
	vec3 sunspot  = reflection ? vec3(0.0) : CalculateSunspot(viewSpacePosition) * pow(visibility, 25) * alpha;
	
	return (gradient + sunspot) * SKY_BRIGHTNESS;
}
