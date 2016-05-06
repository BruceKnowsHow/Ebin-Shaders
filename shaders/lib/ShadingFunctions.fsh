
// Start of #include "/lib/ShadingFunctions.fsh"

// Prerequisites:
//
// uniform sampler2DShadow shadow;
// uniform sampler2D shadowtex1;
//
// uniform mat4 gbufferModelViewInverse;
// uniform mat4 shadowModelView;
// uniform mat4 shadowProjection;
//
// #include "/lib/Settings.glsl"
// #include "/lib/Util.glsl"


struct Shading {      // Contains scalar light levels without any color
	float normal;     // Coefficient of light intensity based on the dot product of the normal vector and the light vector
	float sunlight;
	float skylight;
	float torchlight;
	float ambient;
};

struct Lightmap {    // Contains vector light levels with color
	vec3 sunlight;
	vec3 skylight;
	vec3 ambient;
	vec3 torchlight;
};

vec4 ViewSpaceToWorldSpace(in vec4 viewSpacePosition) {
	return gbufferModelViewInverse * viewSpacePosition;
}

vec4 WorldSpaceToShadowSpace(in vec4 worldSpacePosition) {
	return shadowProjection * shadowModelView * worldSpacePosition;
}

float GetShadowBias(in vec2 shadowProjection) {
	if (!biasShadowMap) return 1.0;

	#ifdef EXTENDED_SHADOW_DISTANCE
		shadowProjection *= 1.165;

		return length8(shadowProjection) * SHADOW_MAP_BIAS + (1.0 - SHADOW_MAP_BIAS);
	#else
		return length (shadowProjection) * SHADOW_MAP_BIAS + (1.0 - SHADOW_MAP_BIAS);
	#endif
}

vec2 BiasShadowMap(in vec2 shadowProjection, out float biasCoeff) {
	biasCoeff = GetShadowBias(shadowProjection);
	return shadowProjection / biasCoeff;
}

vec2 BiasShadowMap(in vec2 shadowProjection) {
	return shadowProjection / GetShadowBias(shadowProjection);
}

vec3 BiasShadowProjection(in vec3 position, out float biasCoeff) {
	biasCoeff = GetShadowBias(position.xy);
	return position / vec3(vec2(biasCoeff), 4.0); // Apply bias to position.xy, shrink z-buffer
}

vec3 BiasShadowProjection(in vec3 position) {
	return position / vec3(vec2(GetShadowBias(position.xy)), 4.0);
}

vec3 	CalculateNoisePattern1(vec2 offset, float size) {
	vec2 coord = texcoord.st;

	coord *= vec2(viewWidth, viewHeight);
	coord = mod(coord + offset, vec2(size));
	coord /= noiseTextureResolution;

	return texture2D(noisetex, coord).xyz;
}

float GetNormalShading(in vec3 normal, in Mask mask) {
	float shading = dot(normal, lightVector);
	      shading = shading * (1.0 - mask.grass       ) + mask.grass       ;
	      shading = shading * (1.0 - mask.leaves * 0.5) + mask.leaves * 0.5;

	return shading;
}

float ComputeDirectSunlight(in vec4 position, in float normalShading) {
	if (normalShading <= 0.0) return 0.0;

	float biasCoeff;
	float sunlight;

	position     = ViewSpaceToWorldSpace(position);
	position     = WorldSpaceToShadowSpace(position);
	position.xyz = BiasShadowProjection(position.xyz, biasCoeff);
	position.xyz = position.xyz * 0.5 + 0.5;

	if (position.x < 0.0 || position.x > 1.0
	||  position.y < 0.0 || position.y > 1.0
	||  position.z < 0.0 || position.z > 1.0
	    ) return 1.0;

	#if defined PCSS

		float vpsSpread = 0.4 / (biasCoeff);
		float avgDepth = 0.0;  //FIXME: It can't constant
		float minDepth = 11.0;
		int c;

		vec2 noise = CalculateNoisePattern1(vec2(0.0), 64.0).xy;

		//Blocker Search
		for(int i = -1; i <= 1; i++) {
			for(int j = -1; j <= 1; j++) {
				vec2 angle = noise * 3.14159 * 2.0;
				mat2 rotation = mat2(cos(angle.x), -sin(angle.x), sin(angle.y), cos(angle.y)); //Random Rotation Matrix

				vec2 lookupPosition = position.xy + (vec2(i, j) / shadowMapResolution) * rotation * vpsSpread;
				float depthSample = texture2DLod(shadowtex1, lookupPosition, 0).x;

				minDepth = min(minDepth, depthSample);
				avgDepth += pow(clamp(position.z - depthSample, 0.0, 0.15), 1.7);
				c++;
			}
		}

		avgDepth /= c;
		avgDepth = pow(avgDepth, 0.5);

		float penumbraSize = avgDepth;

		int count = 0;
		float spread = penumbraSize * 0.02 * vpsSpread + 0.25 / shadowMapResolution;

		biasCoeff *= 1.0 + avgDepth * 40.0;

		//PCF Blur
		for (float i = -3.0; i <= 3.0; i += 1.0) {
			for (float j = -3.0; j <= 3.0; j += 1.0) {
				float angle = noise.x * 3.14159 * 2.0;
				mat2 rotation = mat2(cos(angle), -sin(angle), sin(angle), cos(angle)); //Random Rotation Matrix

				vec2 coord = vec2(i, j) * rotation;
				sunlight += shadow2DLod(shadow, vec3(position.st + coord * spread, position.z), 0).x;
				count++;
			}
		}

		sunlight /= count;

	#elif defined SOFT_SHADOWS
		float spread   = 1.0 * (1.0 - biasCoeff) / shadowMapResolution;

		const float range       = 1.0;
		const float interval    = 1.0;
		const float sampleCount = pow(range / interval * 2.0 + 1.0, 2.0); // Calculating the sample count outside of the for-loop is generally faster.

		for (float i = -range; i <= range; i += interval)
			for (float j = -range; j <= range; j += interval)
				sunlight += shadow2D(shadow, vec3(position.xy + vec2(i, j) * spread, position.z)).x;

		sunlight /= sampleCount; // Average the samples by dividing the sum by the sample count.
	#else
		sunlight = shadow2D(shadow, position.xyz).x;
	#endif

	sunlight = pow2(sunlight); // Fatten the shadow up to soften its penumbra (default hardware-filtered penumbra does not have a satisfying penumbra curve)

	return sunlight;
}

vec3 CalculateShadedFragment(in vec3 diffuse, in Mask mask, in float torchLightmap, in float skyLightmap, in vec3 normal, in vec4 ViewSpacePosition) {
	diffuse = pow(diffuse, vec3(2.2)); // Put diffuse into a linear color space (diffuse should not be previously gamma-adjusted)

	Shading shading;
	shading.normal = GetNormalShading(normal, mask);

	shading.sunlight  = shading.normal;
	shading.sunlight *= ComputeDirectSunlight(ViewSpacePosition, shading.normal);

	shading.torchlight = 1.0 - pow(torchLightmap, 4.0);
	shading.torchlight = 1.0 / pow(shading.torchlight, 2.0) - 1.0;

	shading.skylight = pow(skyLightmap, 4.0);

	shading.ambient = 1.0;


	Lightmap lightmap;
	lightmap.sunlight = shading.sunlight * colorSunlight;

	lightmap.skylight = shading.skylight * sqrt(colorSkylight);

	lightmap.ambient = shading.ambient * vec3(1.0);

	lightmap.torchlight = shading.torchlight * vec3(1.00, 0.25, 0.05);


	vec3 composite = (
	    lightmap.sunlight   * 10.0  * SUN_LIGHT_LEVEL
	+   lightmap.skylight   * 0.4   * SKY_LIGHT_LEVEL
	+   lightmap.ambient    * 0.015 * AMBIENT_LIGHT_LEVEL
	+   lightmap.torchlight         * TORCH_LIGHT_LEVEL
	    ) * diffuse;

	return composite;
}


// End of #include "/lib/ShadingFunctions.fsh"
