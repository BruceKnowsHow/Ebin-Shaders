// Common stuff that doesn't use any global variables


float cubesmooth(in float x) {    // Applies a subtle S-shaped curve, domain [0 to 1]
	return x * x * (3.0 - 2.0 * x);
}

vec2 cubesmooth(in vec2 x) {
	return x * x * (3.0 - 2.0 * x);
}

float square(in float x) {
	return x * x;
}

float pow2(in float x) {
	return x * x;
}

float pow8(in float x) {
	x *= x;
	x *= x;
	return x * x;
}

float root8(in float x) {
	return sqrt(sqrt(sqrt(x)));
}

float length8(in vec2 x) {
	return root8(pow8(x.x) + pow8(x.y));
}

float clamp01(in float x) {
	return clamp(x, 0.0, 1.0);
}

void rotate(inout vec2 vector, in float radians) {
	vector *= mat2(
		cos(radians), -sin(radians),
		sin(radians),  cos(radians));
}

float sum(in vec2 x) {
	return dot(x, vec2(1.0));
}

float sum(in vec3 x) {
	return dot(x, vec3(1.0));
}
