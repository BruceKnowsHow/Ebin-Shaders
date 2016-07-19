const float     planetRadius = 6371.0;
const float atmosphereRadius = 6471.0;

const vec2 radiiSquared = pow(vec2(planetSquared, atmosphereSquared), vec2(2.0));

float AtmosphereLength(in vec3 worldPosition, in vec3 worldDirection) {
	// Returns the length of air visible to the pixel inside the atmosphere
	// Considers the planet's center as the coordinate origin, as per convention
	
	// worldPosition should probably be: vec3(0.0, planetRadius + cameraPosition.y, 0.0)
	// worldDirection is just the normalized worldSpacePosition
	
	bool insideAtmosphere = true; // worldPosition.y < atmosphereRadius
	
	float b  = -dot(worldPosition, worldDirection);
	float bb = b * b;
	vec2  c  = dot(worldPosition, worldPosition) - radiiSquared;
	
	if (insideAtmosphere) { // Uniform condition
		if (bb < c.x && b > 0.0) // If the earth is not visible to the ray, check against the atmosphere instead
			c.x = c.y;
		
		return b * 0.5 + sqrt(bb - c.x); // find the distance to the sphere's near surface
	} else {
		float delta2 = bb - c.y;
		
		if (bb < c.x && b > 0.0)
			return 2.0 * sqrt(max(delta2, 0.0)); // Find the length of the ray passing through the atmosphere, not occluded by the planet
		
		return sqrt(bb - .x) - sqrt(delta2); // find the distance to the sphere's near surface
	}
}
