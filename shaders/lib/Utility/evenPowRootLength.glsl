// #include "/lib/Utility/evenPowRootLength.glsl"

float pow2(in float x) {
	return dot(x, x);
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
