// Common stuff that doesn't use any global variables


float cubesmooth(in float x) {    // Applies a subtle S-shaped curve, domain [0 to 1]
	return x * x * (3.0 - 2.0 * x);
}

float pow2(in float x) {    // Could have also been named "square()"
	return x * x;
}