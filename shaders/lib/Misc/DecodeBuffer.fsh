void DecodeBuffer(in vec2 coord, out vec3 encode, out float buffer0r, out float buffer0g, out float buffer1r, out float buffer1g) {
	encode.rg = texture2D(colortex6, coord).ba;
	
	vec2 buffer0 = Decode16(encode.r);
	buffer0r = buffer0.r;
	buffer0g = buffer0.g;
	
	vec2 buffer1 = Decode16(encode.g);
	buffer1r = buffer1.r;
	buffer1g = buffer1.g;
}
