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
	
    // Initialize the primary ray time.
    float iTime = 0.0;
	
    // Initialize accumulators for Rayleigh and Mie scattering.
    vec3 totalRlh = vec3(0.0, 0.0, 0.0);
    vec3 totalMie = vec3(0.0, 0.0, 0.0);
	
    // Initialize optical depth accumulators for the primary ray.
    float iOdRlh = 0.0;
    float iOdMie = 0.0;
	
    // Calculate the Rayleigh and Mie phases.
    float mu = dot(worldDirection, pSun);
    float mumu = mu * mu;
    float gg = g * g;
    float pRlh = 3.0 / (16.0 * PI) * (1.0 + mumu);
    float pMie = 3.0 / (8.0 * PI) * ((1.0 - gg) * (mumu + 1.0)) / (pow(1.0 + gg - 2.0 * mu * g, 1.5) * (2.0 + gg));
	
    // Sample the primary ray.
    for (int i = 0; i < iSteps; i++) {
        // Calculate the primary ray sample position.
        vec3 iPos = worldPosition + worldDirection * (iTime + iStepSize * 0.5);
		
        // Calculate the height of the sample.
        float iHeight = length(iPos) - rPlanet;
		
        // Calculate the optical depth of the Rayleigh and Mie scattering for this step.
        float odStepRlh = exp(-iHeight / shRlh) * iStepSize;
        float odStepMie = exp(-iHeight / shMie) * iStepSize;
		
        // Accumulate optical depth.
        iOdRlh += odStepRlh;
        iOdMie += odStepMie;
		
        // Calculate the step size of the secondary ray.
        float jStepSize = AtmosphereLength(iPos, pSun, true) / float(jSteps);
		
        // Initialize the secondary ray time.
        float jTime = 0.0;
		
        // Initialize optical depth accumulators for the secondary ray.
        float jOdRlh = 0.0;
        float jOdMie = 0.0;
		
        // Sample the secondary ray.
        for (int j = 0; j < jSteps; j++) {
            // Calculate the secondary ray sample position.
            vec3 jPos = iPos + pSun * (jTime + jStepSize * 0.5);
			
            // Calculate the height of the sample.
            float jHeight = length(jPos) - rPlanet;
			
            // Accumulate the optical depth.
            jOdRlh += exp(-jHeight / shRlh) * jStepSize;
            jOdMie += exp(-jHeight / shMie) * jStepSize;
			
            // Increment the secondary ray time.
            jTime += jStepSize;
        }
		
        // Calculate attenuation.
        vec3 attn = exp(-(kMie * (iOdMie + jOdMie) + kRlh * (iOdRlh + jOdRlh)));
		
        // Accumulate scattering.
        totalRlh += odStepRlh * attn;
        totalMie += odStepMie * attn;
		
        // Increment the primary ray time.
        iTime += iStepSize;
    }
	
    // Calculate and return the final color.
    return iSun * (pRlh * kRlh * totalRlh + pMie * kMie * totalMie);
}

float rsi(vec3 r0, vec3 rd, float sr) {
    // Simplified ray-sphere intersection that assumes
    // the ray starts inside the sphere and that the
    // sphere is centered at the origin. Always intersects.
    float a = dot(rd, rd);
    float b = 2.0 * dot(rd, r0);
    float c = dot(r0, r0) - (sr * sr);
    return (-b + sqrt((b*b) - 4.0*a*c))/(2.0*a);
}

vec3 atmosphere(vec3 r, vec3 r0, vec3 pSun, float iSun, float rPlanet, float rAtmos, vec3 kRlh, float kMie, float shRlh, float shMie, float g) {
	// Normalize the sun and view directions.
    pSun = normalize(pSun);
    r = normalize(r);
	
    // Calculate the step size of the primary ray.
    float iStepSize = rsi(r0, r, rAtmos) / float(iSteps);
	
    // Initialize the primary ray time.
    float iTime = 0.0;
	
    // Initialize accumulators for Rayleigh and Mie scattering.
    vec3 totalRlh = vec3(0,0,0);
    vec3 totalMie = vec3(0,0,0);
	
    // Initialize optical depth accumulators for the primary ray.
    float iOdRlh = 0.0;
    float iOdMie = 0.0;
	
    // Calculate the Rayleigh and Mie phases.
    float mu = dot(r, pSun);
    float mumu = mu * mu;
    float gg = g * g;
    float pRlh = 3.0 / (16.0 * PI) * (1.0 + mumu);
    float pMie = 3.0 / (8.0 * PI) * ((1.0 - gg) * (mumu + 1.0)) / (pow(1.0 + gg - 2.0 * mu * g, 1.5) * (2.0 + gg));
	
    // Sample the primary ray.
    for (int i = 0; i < iSteps; i++) {
		
        // Calculate the primary ray sample position.
        vec3 iPos = r0 + r * (iTime + iStepSize * 0.5);
		
        // Calculate the height of the sample.
        float iHeight = length(iPos) - rPlanet;
		
        // Calculate the optical depth of the Rayleigh and Mie scattering for this step.
        float odStepRlh = exp(-iHeight / shRlh) * iStepSize;
        float odStepMie = exp(-iHeight / shMie) * iStepSize;
		
        // Accumulate optical depth.
        iOdRlh += odStepRlh;
        iOdMie += odStepMie;
		
        // Calculate the step size of the secondary ray.
        float jStepSize = rsi(iPos, pSun, rAtmos) / float(jSteps);
		
        // Initialize the secondary ray time.
        float jTime = 0.0;
		
        // Initialize optical depth accumulators for the secondary ray.
        float jOdRlh = 0.0;
        float jOdMie = 0.0;
		
        // Sample the secondary ray.
        for (int j = 0; j < jSteps; j++) {
			
            // Calculate the secondary ray sample position.
            vec3 jPos = iPos + pSun * (jTime + jStepSize * 0.5);
			
            // Calculate the height of the sample.
            float jHeight = length(jPos) - rPlanet;
			
            // Accumulate the optical depth.
            jOdRlh += exp(-jHeight / shRlh) * jStepSize;
            jOdMie += exp(-jHeight / shMie) * jStepSize;
			
            // Increment the secondary ray time.
            jTime += jStepSize;
        }
		
        // Calculate attenuation.
        vec3 attn = exp(-(kMie * (iOdMie + jOdMie) + kRlh * (iOdRlh + jOdRlh)));
		
        // Accumulate scattering.
        totalRlh += odStepRlh * attn;
        totalMie += odStepMie * attn;
		
        // Increment the primary ray time.
        iTime += iStepSize;
		
    }
	
    // Calculate and return the final color.
    return iSun * (pRlh * kRlh * totalRlh + pMie * kMie * totalMie);
}
