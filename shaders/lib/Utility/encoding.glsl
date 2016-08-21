float Encode4x32F(in vec4 a) {
	a = clamp01(a);
	a = round(a * vec4(254.0, 255.0, 255.0, 252.0));
	
	float z_sign = (a.b < 128.0 ? 1.0 : -1.0);
	a.b = mod(a.b, 128.0);
	
	float encode = dot(a.rgb, exp2(vec3(0.0, 8.0, 16.0)));
	
	float buffer = 0.5 + encode * exp2(-24.0);
	buffer = ldexp(buffer * z_sign, int(a.a - 125.0));
	
	return buffer;
}

vec4 Decode4x32F(in float buffer) {
	int exp;
	float decode = (frexp(buffer, exp) - 0.5) * exp2(24.0);
	
	float z_sign2 = sign(decode);
	decode *= z_sign2;
	
	vec4 b;
	b.rgb  = mod(vec3(decode), exp2(vec3(8.0, 16.0, 24.0)));
	b.gb  -= b.rg;
	b.rgb *= exp2(-vec3(0.0, 8.0, 16.0));
	b.a    = exp + 125.0;
	
	if (z_sign2 < 0.0) b.b += 128.0;
	
	b /= vec4(254.0, 255.0, 255.0, 252.0);
	
	return b;
}

float Encode16(vec2 encodedBuffer) {
	cvec2 encode = vec2(1.0, exp2(8.0));
	
	encodedBuffer = round(encodedBuffer * 255.0);
	
	return dot(encodedBuffer, encode) / (exp2(16.0) - 1.0);
}

vec2 Decode16(float encodedBuffer) {
	cvec2 decode = 1.0 / (exp2(8.0) - 1.0) / vec2(1.0, exp2(8.0));
	
	vec2 decoded;
	
	encodedBuffer *= exp2(16.0) - 1.0;
	
	decoded.r = mod(encodedBuffer, exp2(8.0));
	decoded.g = encodedBuffer - decoded.r;
	
	return decoded * decode;
}

void Decode16(float encodedBuffer, out float buffer0, out float buffer1) {
	cvec2 decode = 1.0 / (exp2(8.0) - 1.0) / vec2(1.0, exp2(8.0));
	
	vec2 decoded;
	
	encodedBuffer *= exp2(16.0) - 1.0;
	
	decoded.r = mod(encodedBuffer, exp2(8.0));
	decoded.g = encodedBuffer - decoded.r;
	
	decoded *= decode;
	
	buffer0 = decoded.r;
	buffer1 = decoded.g;
}

vec3 EncodeColor(vec3 color) { // Prepares the color to be sent through a limited dynamic range pipeline
	return pow(color * 0.001, vec3(1.0 / 2.2));
}

vec3 DecodeColor(vec3 color) {
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
