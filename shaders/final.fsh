#version 120

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D noisetex;

uniform float viewWidth;
uniform float viewHeight;

varying vec2 texcoord;

#include "/lib/Settings.glsl"
#include "/lib/Util.glsl"
#include "/lib/Encoding.glsl"


vec3 Uncharted2Tonemap(in vec3 color) {
	const float A = 0.15, B = 0.5, C = 0.1, D = 0.2, E = 0.02, F = 0.3, W = 11.2;
	const float whiteScale = 1.0 / (((W * (A * W + C * B) + D * E) / (W * (A * W + B) + D * F)) - E / F);
	const float ExposureBias = 2.3 * EXPOSURE;
	
	vec3 curr = ExposureBias * color;
	     curr = ((curr * (A * curr + C * B) + D * E) / (curr * (A * curr + B) + D * F)) - E / F;
	
	color = curr * whiteScale;
	
	return pow(color, vec3(1.0 / 2.2));
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

void main() {
	vec3 color = DecodeColor(texture2D(colortex0, texcoord).rgb);
	
	vec3[8] bloom = GetBloom();
	
	color = mix(color, pow(bloom[0], vec3(BLOOM_CURVE)), BLOOM_AMOUNT);
	
	gl_FragColor = vec4(Uncharted2Tonemap(color), 1.0);
}