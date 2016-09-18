#version 410 compatibility
#define final
#define fsh
#define ShaderStage 7
#include "/lib/Syntax.glsl"

uniform sampler2D colortex1;
uniform sampler2D colortex3;
uniform sampler2D gdepthtex;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

varying vec2 texcoord;
varying vec2 pixelSize;

#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"
#include "/lib/Debug.glsl"
#include "/lib/Fragment/Masks.fsh"

vec3 GetColor(vec2 coord) {
	return DecodeColor(texture2D(colortex3, coord).rgb);
}

float GetDepth(vec2 coord) {
	return texture2D(gdepthtex, coord).x;
}

vec4 CalculateViewSpacePosition(vec2 coord, float depth) {
	vec4 position  = gbufferProjectionInverse * vec4(vec3(coord, depth) * 2.0 - 1.0, 1.0);
	     position /= position.w;
	
	return position;
}

void MotionBlur(inout vec3 color, float depth) {
#ifdef MOTION_BLUR
//	if (mask.hand > 0.5) return;
	
	vec4 position = vec4(vec3(texcoord, depth) * 2.0 - 1.0, 1.0); // Signed [-1.0 to 1.0] screen space position
	
	vec4 previousPosition      = gbufferModelViewInverse * gbufferProjectionInverse * position; // Un-project and un-rotate
	     previousPosition     /= previousPosition.w; // Linearize
	     previousPosition.xyz += cameraPosition - previousCameraPosition; // Add the world-space difference from the previous frame
	     previousPosition      = gbufferPreviousProjection * gbufferPreviousModelView * previousPosition; // Re-rotate and re-project using the previous frame matrices
	     previousPosition.st  /= previousPosition.w; // Un-linearize, swizzle to avoid correcting irrelivant components
	
	cfloat intensity = MOTION_BLUR_INTENSITY * 0.5;
	cfloat maxVelocity = MAX_MOTION_BLUR_AMOUNT * 0.1;
	
	vec2 velocity = (position.st - previousPosition.st) * intensity; // Screen-space motion vector
	     velocity = clamp(velocity, vec2(-maxVelocity), vec2(maxVelocity));
	
	#ifdef VARIABLE_MOTION_BLUR_SAMPLES
	float sampleCount = length(velocity / pixelSize) * VARIABLE_MOTION_BLUR_SAMPLE_COEFFICIENT; // There should be exactly 1 sample for every pixel when the sample coefficient is 1.0
	      sampleCount = floor(clamp(sampleCount, 1, MAX_MOTION_BLUR_SAMPLE_COUNT));
	#else
	cfloat sampleCount = CONSTANT_MOTION_BLUR_SAMPLE_COUNT;
	#endif
	
	vec2 sampleStep = velocity / sampleCount;
	
	color *= 0.001;
	
	for(float i = 1.0; i <= sampleCount; i++) {
		vec2 coord = texcoord - sampleStep * i;
		
		color += pow(texture2D(colortex3, clampScreen(coord, pixelSize)).rgb, vec3(2.2));
	}
	
	color *= 1000.0 / max(sampleCount + 1.0, 1.0);
#endif
}

vec3 GetBloomTile(cint scale, vec2 offset) {
	vec2 coord  = texcoord;
	     coord /= scale;
	     coord += offset + pixelSize;
	
	return DecodeColor(texture2D(colortex1, coord).rgb);
}

vec3[8] GetBloom() {
	vec3[8] bloom;
	
#ifdef BLOOM_ENABLED
	// These arguments should be identical to those in composite2.fsh
	bloom[1] = GetBloomTile(  4, vec2(0.0                         ,                          0.0));
	bloom[2] = GetBloomTile(  8, vec2(0.0                         , 0.25     + pixelSize.y * 2.0));
	bloom[3] = GetBloomTile( 16, vec2(0.125    + pixelSize.x * 2.0, 0.25     + pixelSize.y * 2.0));
	bloom[4] = GetBloomTile( 32, vec2(0.1875   + pixelSize.x * 4.0, 0.25     + pixelSize.y * 2.0));
	bloom[5] = GetBloomTile( 64, vec2(0.125    + pixelSize.x * 2.0, 0.3125   + pixelSize.y * 4.0));
	bloom[6] = GetBloomTile(128, vec2(0.140625 + pixelSize.x * 4.0, 0.3125   + pixelSize.y * 4.0));
	bloom[7] = GetBloomTile(256, vec2(0.125    + pixelSize.x * 2.0, 0.328125 + pixelSize.y * 6.0));
	
	bloom[0] = vec3(0.0);
	
	for (uint index = 1; index <= 7; index++)
		bloom[0] += bloom[index];
	
	bloom[0] /= 7.0;
#endif
	
	return bloom;
}

vec3 Uncharted2Tonemap(vec3 color) {
	cfloat A = 0.5, B = 0.7, C = 0.2, D = 0.2, E = 0.02, F = 0.6, W = 10.0;
	cfloat whiteScale = 1.0 / (((W * (A * W + C * B) + D * E) / (W * (A * W + B) + D * F)) - E / F);
	cfloat ExposureBias = 1.5 * EXPOSURE;
	
	vec3 curr = ExposureBias * color;
	     curr = ((curr * (A * curr + C * B) + D * E) / (curr * (A * curr + B) + D * F)) - E / F;
	
	color = curr * whiteScale;
	
	return pow(color, vec3(1.0 / 2.2));
}

float get8x8Dither(in vec2 coord)
{
	const float[64] ditherPattern = float[64](
		 1, 49, 12, 61,  4, 52, 16, 64,
		33, 17, 45, 29, 36, 20, 48, 32,
		 9, 57,  5, 53, 12, 60,  8, 56,
		41, 25, 37, 21, 44, 28, 40, 24,
		 3, 51, 15, 63,  2, 50, 14, 62,
		35, 19, 47, 31, 34, 18, 46, 30,
		11, 59,  7, 55, 10, 58,  6, 54,
		43, 27, 39, 23, 42, 26, 38, 22
	);

	ivec2 patternCoord = ivec2(mod(coord.x, 8.0), mod(coord.y, 8.0));

	return ditherPattern[patternCoord.y * patternCoord.x] / 65.0;
}


void main() {
	float depth = GetDepth(texcoord);
	vec3  color = GetColor(texcoord);
	
	vec4 viewSpacePosition = CalculateViewSpacePosition(texcoord, depth);
	
	
	MotionBlur(color, depth);
	
	
	vec3[8] bloom = GetBloom();
	
	color = mix(color, pow(bloom[0], vec3(BLOOM_CURVE)), BLOOM_AMOUNT);
	
	color = Uncharted2Tonemap(color);
	
	color = SetSaturationLevel(color, SATURATION);

	color += get8x8Dither(gl_FragCoord.st) / 255.0;

	gl_FragData[0] = vec4(color, 1.0);
	
	exit();
}
