float Encode16(in vec2 buffer) {
	cvec2 encode = vec2(1.0, exp2(8.0));
	
	buffer = round(buffer * 255.0);
	
	return dot(buffer, encode) / (exp2(16.0) - 1.0);
}

vec2 Decode16(in float buffer) {
	cvec2 decode = 1.0 / (exp2(8.0) - 1.0) / vec2(1.0, exp2(8.0));
	
	vec2 decoded;
	
	buffer *= exp2(16.0) - 1.0;
	
	decoded.r = mod(buffer, exp2(8.0));
	decoded.g = buffer - decoded.r;
	
	return decoded * decode;
}

vec3 EncodeColor(in vec3 color) { // Prepares the color to be sent through a limited dynamic range pipeline
	return pow(color * 0.001, vec3(1.0 / 2.2));
}

vec3 DecodeColor(in vec3 color) {
	return pow(color, vec3(2.2)) * 1000.0;
}

vec2 EncodeNormal(vec3 normal) {
    float p = sqrt(normal.z * 8.0 + 8.0);
    return vec2(normal.xy / p + 0.5);
}

vec3 DecodeNormal(vec2 encodedNormal) {
    vec2 fenc = encodedNormal * 4.0 - 2.0;
	float f = lengthSquared(fenc);
	float g = sqrt(1.0 - f * 0.25);
	return vec3(fenc * g, 1.0 - f * 0.5);
}

void DecodeBuffer(in vec2 coord, sampler2D buffer, out vec3 encode, out float buffer0r, out float buffer0g, out float buffer1r, out float buffer1g) {
	encode.rg = texture2D(buffer, coord).rg;
	
	vec2 buffer0 = Decode16(encode.r);
	buffer0r = buffer0.r;
	buffer0g = buffer0.g;
	
	vec2 buffer1 = Decode16(encode.g);
	buffer1r = buffer1.r;
	buffer1g = buffer1.g;
}
