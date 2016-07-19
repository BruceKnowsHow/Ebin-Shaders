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
	
	if (insideAtmosphere) {
		// Start with a ray-sphere intersection test for the planet
		float b = -dot(worldPosition, worldDirection);
		float c = worldPositionSquared - planetSquared;
		
		if  (b < c) // If the earth is not visible to the ray
			c = worldPositionSquared - atmosphereSquared;
		
		else return b * 0.5 + sqrt(b * b - c); // find the distance to the sphere's near surface
	} else {
		return 0.0;
	}
}
