float cubesmooth(in float x) { // Applies a subtle S-shaped curve, domain [0 to 1]
	return x * x * (3.0 - 2.0 * x);
}

vec2 cubesmooth(in vec2 x) {
	return x * x * (3.0 - 2.0 * x);
}

float cosmooth(in float x) { // Same concept as cubesmooth, slightly different distribution
	return 0.5 - cos(x * PI) * 0.5;
}

vec2 cosmooth(in vec2 x) {
	return 0.5 - cos(x * PI) * 0.5;
}