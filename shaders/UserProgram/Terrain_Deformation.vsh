vec3 UserDeformation(vec3 position) {
	position.y -= 20.0;
#if !defined gbuffers_shadow
	position.y += 1.6;
#endif
	position.xy = rotate(position.xy, position.x * 0.002 + radians(-52.0));
	position.y += 20.0;
#if !defined gbuffers_shadow
	position.y -= 1.6;
#endif
	return position;
}

vec3 Globe(vec3 position, cfloat radius) {
	position.y -= length2(position.xz) / radius;
	
	return position;
}

vec3 Acid(vec3 position) {
	position.xy = rotate(position.xy, sin(length2(position.xz) * 0.00005) * 0.8);
	
	return position;
}

vec3 TerrainDeformation(vec3 position) {
	
#ifdef DEFORM
	
	#if !defined gbuffers_shadow
		position += gbufferModelViewInverse[3].xyz;
	#endif
	
	#if DEFORMATION == 1
		
		position = Globe(position, 5000.0);
		
	#elif DEFORMATION == 2
		
		position = Acid(position);
		
	#else
		
		position = UserDeformation(position);
		
	#endif
	
	#if !defined gbuffers_shadow
		position -= gbufferModelViewInverse[3].xyz;
	#endif
	
#endif
	
	return position;
}
