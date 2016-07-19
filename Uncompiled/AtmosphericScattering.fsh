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
	
	vec2 delta = sqrt(max(bb - c, 0.0));
	
	if (insideAtmosphere) { // Uniform condition
		if (bb < c.x && b > 0.0) // If the earth is not visible to the ray, check against the atmosphere instead
			delta.x = delta.y;
		
		return b * 0.5 + delta.x; // find the distance to the sphere's near surface
	} else {
		if (bb < c.x && b > 0.0)
			return 2.0 * delta.y; // Find the length of the ray passing through the atmosphere, not occluded by the planet
		
		return delta.x - delta.y;
	}
}
