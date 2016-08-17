vec2 rotate(in vec2 vector, float radians) {
	return vector *= mat2(
		cos(radians), -sin(radians),
		sin(radians),  cos(radians));
}

vec2 rotateDeg(in vec2 vector, float degrees) {
	degrees = radians(degrees);
	
	return vector *= mat2(
		cos(degrees), -sin(degrees),
		sin(degrees),  cos(degrees));
}
