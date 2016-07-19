const float     planetRadius = 6371.0;
const float atmosphereRadius = 6471.0;

const float     planetSquared =     planetRadius * planetRadius;
const float atmosphereSquared = atmosphereRadius * atmosphereRadius;

float AtmosphereLength(in vec3 worldPosition, in vec3 worldDirection) {
	// Returns the length of air visible to the pixel inside the atmosphere
	// Considers the planet's center as the coordinate origin, as per convention
	
	// worldPosition should probably be: vec3(0.0, planetRadius + cameraPosition.y, 0.0)
	// worldDirection is just the normalized worldSpacePosition
	
	float worldPositionSquared = dot(worldPosition, worldPosition);
	
	bool insideAtmosphere = true; // worldPosition.y < atmosphereRadius, uniform condition
	
	float b  = -dot(worldPosition, worldDirection);
	float bb = b * b;
	float c1 = worldPositionSquared - planetSquared;
	float c2 = worldPositionSquared - atmosphereSquared;
	
	if (insideAtmosphere) {
		if (bb < c1 && b > 0.0) // If the earth is not visible to the ray, check against the atmosphere instead
			c1 = c2;
		
		return b * 0.5 + sqrt(bb - c1); // find the distance to the sphere's near surface
	} else {
		float delta2 = bb - c2;
		
		if (bb < c1 && b > 0.0)
			return 2.0 * sqrt(max(delta2, 0.0)); // Find the length of the ray passing through the atmosphere, not occluded by the planet
		
		return sqrt(bb - c1) - sqrt(delta2); // find the distance to the sphere's near surface
	}
}
