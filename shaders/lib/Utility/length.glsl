float lengthSquared(vec2 x) {
	return dot(x, x);
}

float lengthSquared(vec3 x) {
	return dot(x, x);
}

float length8(vec2 x) {
	x *= x;
	x *= x;
	return sqrt(sqrt(sqrt(dot(x, x))));
}

float lengthN(vec2 x, float N) {
	x = pow(x * x, swizzle.aa * N);
	return pow(dot(x, swizzle.rr), 1.0 / N);
}
