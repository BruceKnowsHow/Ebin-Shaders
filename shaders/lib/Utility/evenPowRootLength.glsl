float pow2(float x) {
	return dot(x, x);
}

float pow8(float x) {
	x *= x;
	x *= x;
	return x * x;
}

float root8(float x) {
	return sqrt(sqrt(sqrt(x)));
}

float length8(vec2 x) {
	return root8(pow8(x.x) + pow8(x.y));
}
