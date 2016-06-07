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

float Encode24(in vec2 buffer) {
	cvec2 encode = vec2(1.0, exp2(12.0));
	
	buffer = round(buffer * (exp2(12.0) - 1.0));
	
	return dot(buffer, encode);
}

vec2 Decode24(in float buffer) {
	cvec2 decode = 1.0 / (exp2(12.0) - 1.0) / vec2(1.0, exp2(12.0));
	
	vec2 decoded;
	
	decoded.r = mod(buffer, exp2(12.0));
	decoded.g = buffer - decoded.r;
	
	return decoded * decode;
}

float Encode8to32(in float buffer0, in float buffer1, in float buffer2) {
	cvec3 encode = vec3(1.0, exp2(8.0), exp2(16.0));
	
	vec3 buffer = vec3(buffer0, buffer1, buffer2);
	     buffer = round(buffer * 255.0);
	
	return dot(buffer, encode);
}

void Decode32to8(in float buffer, out float buffer0, out float buffer1, out float buffer2) {
	buffer0 = mod(buffer          , exp2( 8.0));
	buffer1 = mod(buffer - buffer0, exp2(16.0));
	buffer2 = buffer - buffer1 - buffer0;
	
	buffer0 /= 255.0;
	buffer1 /= 255.0 * exp2( 8.0);
	buffer2 /= 255.0 * exp2(16.0);
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