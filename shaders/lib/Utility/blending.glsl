vec3 screen(in vec3 a, in vec3 b) {
	return 1.0 - (1.0 - a) * (1.0 - b);
}

vec3 overlay(in vec3 a, in vec3 b) {
	bvec3 mult = lessThan(a, vec3(0.5));
	
	vec3 screen = screen(a, b);
	
	return mix(screen, 2.0 * a * b, mult);
}

#define hard_light(a, b) overlay(b, a)
