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
		float b  = -dot(worldPosition, worldDirection);
		float bb = b * b;
		float c  = worldPositionSquared - planetSquared;
		
		if (bb < c && b > 0.0) // If the earth is not visible to the ray, check against the atmosphere instead
			c = worldPositionSquared - atmosphereSquared;
		
		return b * 0.5 + sqrt(bb - c); // find the distance to the sphere's near surface
	} else {
		float b  = -dot(worldPosition, worldDirection);
		float bb = b * b;
		float c1 = worldPositionSquared - planetSquared;
		float c2 = worldPositionSquared - atmosphereSquared;
		
		if  (bb < c1 && b > 0.0) {
			float delta = bb - c2;
			
			return 2.0 * sqrt(max(delta, 0.0)); // Find the length of the ray passing through the atmosphere, not occluded by the planet
		}
		
		float distEarth      = b * 0.5 + sqrt(bb - c1);
		float distAtmosphere = b * 0.5 + sqrt(bb - c2);
		
		return distEarth - distAtmosphere; // find the distance to the sphere's near surface
	}
}
