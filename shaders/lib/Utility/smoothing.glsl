float cubesmooth(float x) { // Applies a subtle S-shaped curve, doma[0 to 1]
	return x * x * (3.0 - 2.0 * x);
}

vec2 cubesmooth(vec2 x) {
	return x * x * (3.0 - 2.0 * x);
}

#define cosmooth(x) (0.5 - cos(x * PI) * 0.5) // Same concept as cubesmooth, slightly different distribution
