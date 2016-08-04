vec3 CalculateVertexDisplacements(vec3 worldSpacePosition, float skyLightmap) {
	worldSpacePosition += cameraPosition.xyz;
	
	vec3 wave = vec3(0.0);
	
	float skylightWeight = skyLightmap;
	float grassWeight    = float(fract(texcoord.t * 64.0) < 0.01);
	
	switch(int(mc_Entity.x)) {
		case 31:
		case 37:
		case 38:
		case 59:  wave += GetWavingGrass(worldSpacePosition, skylightWeight * grassWeight); break;
		case 18:
		case 161: wave += GetWavingLeaves(worldSpacePosition, skylightWeight); break;
		case 8:
		case 9:
		case 111: wave += GetWavingWater(worldSpacePosition, 1.0); break;
	}
	
	return wave;
}
