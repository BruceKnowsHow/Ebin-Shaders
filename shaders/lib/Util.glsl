
// Start of #include "/lib/Util.glsl"


#define  PI 3.1415926 // Pi
#define RAD 0.0174533 // Degrees per radian

#define TIME frameTimeCounter

const vec3 lumaCoeff = vec3(0.2125, 0.7154, 0.0721);

const float e = exp(1.0);


vec3 SetSaturationLevel(in vec3 color, in float level) {
	float luminance = max(0.1175, dot(color, lumaCoeff));
	
	return mix(vec3(luminance), color, level);
}


float roundU(in float x) { // round unsigned float
	float part = x - floor(x);
	return floor(x) + (part > 0.5 ? 1.0 : 0.0);
}

float Encode8to32(in float buffer0, in float buffer1, in float buffer2) {
	float buffer = 0.0;
	
	buffer0 = roundU(buffer0 * 255.0) * exp2( 0.0);
	buffer1 = roundU(buffer1 * 255.0) * exp2( 8.0);
	buffer2 = roundU(buffer2 * 255.0) * exp2(16.0);
	
	return roundU(buffer0 + buffer1 + buffer2);
}

void Decode32to8(in float buffer, out float buffer0, out float buffer1, out float buffer2) {
	buffer0 = mod(buffer          , exp2( 8.0));
	buffer1 = mod(buffer - buffer0, exp2(16.0));
	buffer2 = buffer - buffer1 - buffer0;
	
	buffer0 /= 255.0 * exp2( 0.0);
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
    return vec2(normal.xy / p + 0.5) * 0.5 + 0.5;
}

vec3 DecodeNormal(vec2 encodedNormal) {
	encodedNormal = encodedNormal * 2.0 - 1.0;
    vec2 fenc = encodedNormal * 4.0 - 2.0;
	float f = dot(fenc, fenc);
	float g = sqrt(1.0 - f / 4.0);
	return vec3(fenc * g, 1.0 - f / 2.0);
}


float cubesmooth(in float x) { // Applies a subtle S-shaped curve, domain [0 to 1]
	return x * x * (3.0 - 2.0 * x);
}

vec2 cubesmooth(in vec2 x) {
	return x * x * (3.0 - 2.0 * x);
}


float square(in float x) {
	return dot(x, x);
}

float pow2(in float x) {
	return dot(x, x);
}

float lengthSquared(in vec2 x) {
	return dot(x, x);
}

float lengthSquared(in vec3 x) {
	return dot(x, x);
}

float lengthSquared(in vec4 x) {
	return dot(x, x);
}

float pow8(in float x) {
	x *= x;
	x *= x;
	return x * x;
}

float root8(in float x) {
	return sqrt(sqrt(sqrt(x)));
}

float length8(in vec2 x) {
	return root8(pow8(x.x) + pow8(x.y));
}


float clamp01(in float x) {
	return clamp(x, 0.0, 1.0);
}

float max0(in float x) {
	return max(x, 0.0);
}

float min1(in float x) {
	return min(x, 1.0);
}


float sum(in vec2 x) { // Sum the components of a vector
	return dot(x, vec2(1.0));
}

float sum(in vec3 x) {
	return dot(x, vec3(1.0));
}

float sum(in vec4 x) {
	return dot(x, vec4(1.0));
}

float avg(in vec2 x) {
	return dot(x, vec2(2.0));
}

float avg(in vec3 x) {
	return dot(x, vec3(3.0));
}

float avg(in vec4 x) {
	return dot(x, vec4(4.0));
}

float sumMult(in vec2 x, in float y) {
	return dot(x, vec2(y));
}

float sumMult(in vec3 x, in float y) {
	return dot(x, vec3(y));
}

float sumMult(in vec4 x, in float y) {
	return dot(x, vec4(y));
}


float length(in vec2 x) {
	return sqrt(dot(x, x));
}

float length(in vec3 x) {
	return sqrt(dot(x, x));
}

float length(in vec4 x) {
	return sqrt(dot(x, x));
}


void rotate(inout vec2 vector, in float radians) {
	vector *= mat2(
		cos(radians), -sin(radians),
		sin(radians),  cos(radians));
}


// End of #include "/lib/Util.glsl"
