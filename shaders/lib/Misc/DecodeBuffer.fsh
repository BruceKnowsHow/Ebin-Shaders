#if defined composite0
void DecodeBuffer(in vec2 coord, out vec2 encode, out float buffer0r, out float buffer0g, out float buffer1r, out float buffer1g) {
	encode.rg = texture2D(colortex4, coord).ba;
	
	vec2 buffer0 = Decode16(encode.r);
	buffer0r = buffer0.r;
	buffer0g = buffer0.g;
	
	vec2 buffer1 = Decode16(encode.g);
	buffer1r = buffer1.r;
	buffer1g = buffer1.g;
}
#elif defined composite1
void DecodeBuffer(in vec2 coord, out vec4 encode, out vec3 normal, out float buffer0r, out float buffer0g, out float buffer1r, out float buffer1g) {
	encode = texture2D(colortex4, coord);
	
	normal = DecodeNormal(encode.xy);
	
	vec2 buffer0 = Decode16(encode.b);
	buffer0r = buffer0.r;
	buffer0g = buffer0.g;
	
	vec2 buffer1 = Decode16(encode.a);
	buffer1r = buffer1.r;
	buffer1g = buffer1.g;
}
#elif defined composite2
void DecodeBuffer(in vec2 coord, out vec2 encode, out float buffer0r, out float buffer0g, out float buffer1r, out float buffer1g) {
	encode.rg = texture2D(colortex4, coord).ba;
	
	vec2 buffer0 = Decode16(encode.r);
	buffer0r = buffer0.r;
	buffer0g = buffer0.g;
	
	vec2 buffer1 = Decode16(encode.g);
	buffer1r = buffer1.r;
	buffer1g = buffer1.g;
}

void DecodeTransparentBuffer(in vec2 coord, out float buffer0r, out float buffer0g) {
	float encode = texture2D(colortex0, coord).b;
	
	vec2 buffer0 = Decode16(encode);
	buffer0r = buffer0.r;
	buffer0g = buffer0.g;
}
#endif
