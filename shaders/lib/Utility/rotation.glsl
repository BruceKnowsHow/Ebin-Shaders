void rotate(inout vec2 vector, float radians) {
	vector *= mat2(
		cos(radians), -sin(radians),
		sin(radians),  cos(radians));
}

void rotateDeg(inout vec2 vector, float degrees) {
	degrees = radians(degrees);
	
	vector *= mat2(
		cos(degrees), -sin(degrees),
		sin(degrees),  cos(degrees));
}
