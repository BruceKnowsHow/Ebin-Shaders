// #include "/lib/Utility/clamping.glsl"

float max0(in float x) {
	return max(x, 0.0);
}

float min1(in float x) {
	return min(x, 1.0);
}

float clamp01(in float x) {
	return clamp(x, 0.0, 1.0);
}
