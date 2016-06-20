float ComputeShadows(in vec3 position, in float biasCoeff) { // Hard shadows
	return pow2(shadow2D(shadow, position.xyz).x);
}
