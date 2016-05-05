#version 120

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D gdepthtex;
uniform sampler2D noisetex;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform float viewWidth;
uniform float viewHeight;

uniform float near;
uniform float far;

varying vec2 texcoord;

#include "/lib/Settings.glsl"
#include "/lib/Util.glsl"
#include "/lib/Masks.glsl"
#include "/lib/CalculateFogFactor.glsl"


vec3 GetColor(in vec2 coord) {
	return DecodeColor(texture2D(colortex0, coord).rgb);
}

float GetDepth(in vec2 coord) {
	return texture2D(gdepthtex, coord).x;
}

float ExpToLinearDepth(in float depth) {
	return 2.0 * near * (far + near - depth * (far - near));
}

vec4 CalculateViewSpacePosition(in vec2 coord, in float depth) {
	vec4 position  = gbufferProjectionInverse * vec4(vec3(coord, depth) * 2.0 - 1.0, 1.0);
	     position /= position.w;
	
	return position;
}

float GetMaterialID(in vec2 coord) {
	return texture2D(colortex3, texcoord).b;
}

void MotionBlur(inout vec3 color, in float depth, in Mask mask) {
	if (mask.hand > 0.5) return;
	
	vec4 position = vec4(vec3(texcoord, depth) * 2.0 - 1.0, 1.0); // Signed [-1.0 to 1.0] screen space position
	
	vec4 previousPosition      = gbufferModelViewInverse * gbufferProjectionInverse * position; // Un-project and un-rotate
	     previousPosition     /= previousPosition.w; // Linearize
	     previousPosition.xyz += cameraPosition - previousCameraPosition; // Add the world-space difference from the previous frame
	     previousPosition      = gbufferPreviousProjection * gbufferPreviousModelView * previousPosition; // Re-rotate and re-project using the previous frame matrices
	     previousPosition.st  /= previousPosition.w; // Un-linearize, swizzle to avoid correcting irrelivant components
	
	const float intensity = MOTION_BLUR_INTENSITY;
	const float maxVelocity = MAX_MOTION_BLUR_AMOUNT * 0.1;
	
	vec2 velocity = (position.st - previousPosition.st) * intensity; // Screen-space motion vector
	     velocity = clamp(velocity, vec2(-maxVelocity), vec2(maxVelocity));
	
	#ifdef VARIABLE_MOTION_BLUR_SAMPLES
	float sampleCount = length(velocity * vec2(viewWidth, viewHeight)) * VARIABLE_MOTION_BLUR_SAMPLE_COEFFICIENT; // There should be exactly 1 sample for every pixel when the sample coefficient is 1.0
	      sampleCount = floor(clamp(sampleCount, 1.0, MAX_MOTION_BLUR_SAMPLE_COUNT));
	#else
	const float sampleCount = CONSTANT_MOTION_BLUR_SAMPLE_COUNT;
	#endif
	
	vec2 sampleStep = velocity / sampleCount;
	
	vec2 pixelSize = 1.0 / vec2(viewWidth, viewHeight);
	vec2 minCoord  = pixelSize;
	vec2 maxCoord  = 1.0 - pixelSize;
	
	color *= 0.001;
	
	for(float i = 1.0; i <= sampleCount; i++) {
		vec2 coord = texcoord - sampleStep * i;
		
		color += pow(texture2D(colortex0, clamp(coord, minCoord, maxCoord)).rgb, vec3(2.2));
	}
	
	color *= 1000.0 / max(sampleCount + 1.0, 1.0);
}

vec3 GetBloomTile(const int scale, vec2 offset) {
	vec2 pixelSize = 1.0 / vec2(viewWidth, viewHeight);
	
	vec2 coord  = texcoord;
	     coord /= scale;
	     coord += offset + pixelSize;
	
	return DecodeColor(texture2D(colortex2, coord).rgb);
}

vec3[8] GetBloom() {
	vec2 pixelSize = 1.0 / vec2(viewWidth, viewHeight);
	
	vec3[8] bloom;
	
	// These arguments should be identical to those in composite2.fsh
	bloom[1] = GetBloomTile(  4, vec2(0.0                         ,                          0.0));
	bloom[2] = GetBloomTile(  8, vec2(0.0                         , 0.25     + pixelSize.y * 2.0));
	bloom[3] = GetBloomTile( 16, vec2(0.125    + pixelSize.x * 2.0, 0.25     + pixelSize.y * 2.0));
	bloom[4] = GetBloomTile( 32, vec2(0.1875   + pixelSize.x * 4.0, 0.25     + pixelSize.y * 2.0));
	bloom[5] = GetBloomTile( 64, vec2(0.125    + pixelSize.x * 2.0, 0.3125   + pixelSize.y * 4.0));
	bloom[6] = GetBloomTile(128, vec2(0.140625 + pixelSize.x * 4.0, 0.3125   + pixelSize.y * 4.0));
	bloom[7] = GetBloomTile(256, vec2(0.125    + pixelSize.x * 2.0, 0.328125 + pixelSize.y * 6.0));
	
	bloom[0] = vec3(0.0);
	
	for (int index = 1; index < bloom.length(); index++)
		bloom[0] += bloom[index];
	
	bloom[0] /= bloom.length() - 1.0;
	
	return bloom;
}

vec3 Uncharted2Tonemap(in vec3 color) {
	const float A = 0.15, B = 0.5, C = 0.1, D = 0.2, E = 0.02, F = 0.3, W = 11.2;
	const float whiteScale = 1.0 / (((W * (A * W + C * B) + D * E) / (W * (A * W + B) + D * F)) - E / F);
	const float ExposureBias = 2.3 * EXPOSURE;
	
	vec3 curr = ExposureBias * color;
	     curr = ((curr * (A * curr + C * B) + D * E) / (curr * (A * curr + B) + D * F)) - E / F;
	
	color = curr * whiteScale;
	
	return pow(color, vec3(1.0 / 2.2));
}

void SetSaturationLevel(inout vec3 color, in float level) {
	const vec3 lumaCoeff = vec3(0.2125, 0.7154, 0.0721);
	
	float luminance = dot(color, lumaCoeff);
	
	color = mix(vec3(luminance), color, level);
}


void main() {
	Mask mask;
	CalculateMasks(mask, GetMaterialID(texcoord), true);
	
	
	float depth = GetDepth(texcoord);
	vec3  color = GetColor(texcoord);
	
	vec4 viewSpacePosition = CalculateViewSpacePosition(texcoord, depth);
	
	
	#ifdef MOTION_BLUR
	MotionBlur(color, depth, mask);
	#endif
	
	vec3[8] bloom = GetBloom();
	
	color = mix(color, pow(bloom[0], vec3(BLOOM_CURVE)), BLOOM_AMOUNT);
	
	SetSaturationLevel(color, 1.07);
	
	
	gl_FragColor = vec4(Uncharted2Tonemap(color), 1.0);
}