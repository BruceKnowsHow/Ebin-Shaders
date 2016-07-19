#define PI 3.141592
#define iSteps 16
#define jSteps 8

const float     planetRadius = 6371.0;
const float atmosphereRadius = 6471.0;

const vec2 radiiSquared = pow(vec2(planetSquared, atmosphereSquared), vec2(2.0));

float AtmosphereLength(in vec3 worldPosition, in vec3 worldDirection, const bool definatelyInAtmosphere) {
	// Returns the length of air visible to the pixel inside the atmosphere
	// Considers the planet's center as the coordinate origin, as per convention
	
	// worldPosition should probably be: vec3(0.0, planetRadius + cameraPosition.y, 0.0)
	// worldDirection is just the normalized worldSpacePosition
	
	float b  = -dot(worldPosition, worldDirection);
	float bb = b * b;
	vec2  c  = dot(worldPosition, worldPosition) - radiiSquared;
	
	vec2 delta = sqrt(max(bb - c, 0.0));
	
	if (definatelyInAtmosphere || worldPosition.y < atmosphereRadius) { // Uniform condition
		if (bb < c.x && b > 0.0) // If the earth is not visible to the ray, check against the atmosphere instead
			delta.x = delta.y;
		
		return b * 0.5 + delta.x; // find the distance to the sphere's near surface
	} else {
		if (bb < c.x && b > 0.0)
			return 2.0 * delta.y; // Find the length of the ray passing through the atmosphere, not occluded by the planet
		
		return delta.x - delta.y;
	}
}

vec3 ComputeAtmosphericSky(vec3 worldPosition, vec3 playerSpacePosition, vec3 pSun, float iSun, float rPlanet, float rAtmos, vec3 kRlh, float kMie, float shRlh, float shMie, float g) {
	vec3 worldDirection = normalize(playerSpacePosition);
	
	// Calculate the step size of the primary ray.
    float iStepSize = AtmosphereLength(worldPosition, worldDirection, false) / float(iSteps);
	
    float iCount = 0.0; // Initialize the primary ray counter
	
    // Initialize accumulators for Rayleigh and Mie scattering.
    mat2x3 accumulator = mat2x3(0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
	
    // Initialize optical depth accumulators for the primary ray.
	vec4 opticalDepth = vec4(0.0); // .rg = rayleigh & mie depth for the "i" iterator, .ba represent the same for the "j" iterator
	
	vec2 invScatterHeight = -1.0 / vec2(shRlh, shMie);
	
    // Sample the primary ray.
    for (int i = 0; i < iSteps; i++) {
        vec3 iPos = r0 + r * (iCount + iStepSize * 0.5); // Calculate the primary ray sample position
		
        float iHeight = length(iPos) - rPlanet; // Calculate the height of the sample
		
		vec2 opticalStep = exp(iHeight * invScatterHeight) * iStepSize; // Calculate the optical depth of the Rayleigh and Mie scattering for this step
		
		opticalDepth.rg += opticalStep; // Accumulate optical depth
		
        float jStepSize = AtmosphereLength(iPos, pSun, true) / float(jSteps); // Calculate the step size of the secondary ray
		
        float jCount = 0.0; // Initialize the secondary ray counter
		
        // Sample the secondary ray.
        for (int j = 0; j < jSteps; j++) {
            vec3 jPos = iPos + pSun * (jCount + jStepSize * 0.5); // Calculate the secondary ray sample position
			
            float jHeight = length(jPos) - rPlanet; // Calculate the height of the sample
			
			opticalDepth.ba += exp(jHeight * invScatterHeight) * jStepSize; // Accumulate the optical depth
			
            jCount += jStepSize; // Increment the secondary ray counter
        }
		
        // Calculate attenuation
        vec3 attn = exp(-(kRlh * (opticalDepth.r + opticalDepth.b) + kMie * (opticalDepth.g + opticalDepth.a)));
		
        accumulator += opticalStep.rrrggg * attn; // Accumulate scattering
		
        iCount += iStepSize; // Increment the primary ray counter
    }
	
	// Calculate the Rayleigh and Mie phases.
    float mu = dot(r, pSun);
    float mumu = mu * mu;
    float gg = g * g;
    float pRlh = 3.0 / (16.0 * PI) * (1.0 + mumu);
    float pMie = 3.0 / (8.0 * PI) * ((1.0 - gg) * (mumu + 1.0)) / (pow(1.0 + gg - 2.0 * mu * g, 1.5) * (2.0 + gg));
	
    // Calculate and return the final color.
    return iSun * (pRlh * kRlh * accumulator[0] + pMie * kMie * accumulator[1]);
}
