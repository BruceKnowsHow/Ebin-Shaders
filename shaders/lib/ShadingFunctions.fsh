
// Start of #include "/lib/ShadingFunctions.fsh"

// Prerequisites:
//
// uniform sampler2D shadowtex1;
// uniform sampler2DShadow shadow;
// uniform sampler2D noisetex;
//
// uniform mat4 gbufferModelViewInverse;
// uniform mat4 shadowModelView;
// uniform mat4 shadowProjection;
//
// varying vec2 texcoord
//
// uniform float viewWidth;
// uniform float viewHeight;
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

#include "/lib/BiasFunctions.glsl"

vec2 GetDitherred2DNoise(in vec2 coord, in float n) { // Returns a random noise pattern ranging {-1.0 to 1.0} that repeats every n pixels
	coord *= vec2(viewWidth, viewHeight);
	coord  = mod(coord, vec2(n));
	coord /= noiseTextureResolution;
	return texture2D(noisetex, coord).xy;
}

float GetLambertianShading(in vec3 normal, in Mask mask) {
	float shading = dot(normal, lightVector);
	      shading = shading * (1.0 - mask.grass       ) + mask.grass       ;
	      shading = shading * (1.0 - mask.leaves * 0.5) + mask.leaves * 0.5;

	return shading;
}

float GetOrenNayarShading(in vec4 viewSpacePosition, in vec3 normal, in float roughness, in Mask mask) {
	//float shading = dot(normal, lightVector);

	vec3 lightColor = colorSunlight;

	normal = normalize(normal);
	vec3 eyeDir = normalize(viewSpacePosition.xyz);

	float NdotL = dot(normal, lightVector);
	float NdotV = dot(normal, eyeDir);

	float angleVN = acos(NdotV);
	float angleLN = acos(NdotL);

	float alpha = max(angleVN, angleLN);
	float beta = min(angleVN, angleLN);
	float gamma = dot(eyeDir - normal * dot(eyeDir, normal), lightVector - normal * dot(lightVector, normal));

	float roughnessSquared = square(roughness);

	float A = 1.0 - 0.5 * (roughnessSquared / (roughnessSquared + 0.57));
	float B = 0.45 * (roughnessSquared / (roughnessSquared + 0.09));
	float C = sin(alpha) * tan(beta);

	float L1 = max(0.0, NdotL) * (A + B * max(0.0, gamma) * C);


	L1 = L1 * (1.0 - mask.grass       ) + mask.grass       ;
	//L1 = L1 * (1.0 - mask.leaves * 0.5) + mask.leaves * 0.5;

	return L1;
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

	#if SHADOW_TYPE == 3 // Variable softness
		float vpsSpread = 0.4 / biasCoeff;

		vec2 randomAngle = GetDitherred2DNoise(gl_FragCoord.st / vec2(viewWidth, viewHeight), 64.0).xy * PI * 2.0;

		mat2 blockerRotation = mat2(cos(randomAngle.x), -sin(randomAngle.x),
		                            sin(randomAngle.y),  cos(randomAngle.y)); //Random Rotation Matrix for blocker, high noise

		mat2 pcfRotation = mat2(cos(randomAngle.x), -sin(randomAngle.x),
													 	sin(randomAngle.x),  cos(randomAngle.x)); //Random Rotation Matrix for blocker, high noise

		float range       = 1;
		float sampleCount = pow(range * 2.0 + 1.0, 2.0);

		float avgDepth = 0.0;
		//Blocker Search
		for(float i = -range; i <= range; i++) {
			for(float j = -range; j <= range; j++) {
				vec2 lookupPosition = position.xy + vec2(i, j) * 8 / shadowMapResolution * blockerRotation * vpsSpread;
				float depthSample = texture2DLod(shadowtex1, lookupPosition, 0).x;

				avgDepth += pow(clamp(position.z - depthSample, 0.0, 1.0), 1.7);
			}
		}

		avgDepth /= sampleCount;
		avgDepth  = sqrt(avgDepth);

		float spread = avgDepth * 0.02 * vpsSpread + 0.45 / shadowMapResolution;

		range       = 2.0;
		sampleCount = pow(range * 2.0 + 1.0, 2.0);

		//PCF Blur
		for (float i = -range; i <= range; i++) {
			for (float j = -range; j <= range; j++) {
				vec2 coord = vec2(i, j) * pcfRotation;

				sunlight += shadow2DLod(shadow, vec3(coord * spread + position.st, position.z), 0).x;
			}
		}

		sunlight /= sampleCount;

	#elif SHADOW_TYPE == 2 // Fixed softness
		float spread   = 1.0 * (1.0 - biasCoeff) / shadowMapResolution;

		const float range       = 1.0;
		const float interval    = 1.0;
		const float sampleCount = pow(range / interval * 2.0 + 1.0, 2.0); // Calculating the sample count outside of the for-loop is generally faster.

		for (float i = -range; i <= range; i += interval)
			for (float j = -range; j <= range; j += interval)
				sunlight += shadow2D(shadow, vec3(position.xy + vec2(i, j) * spread, position.z)).x;

		sunlight /= sampleCount; // Average the samples by dividing the sum by the sample count.

		sunlight = pow2(sunlight);
	#else // Hard
		sunlight = shadow2D(shadow, position.xyz).x;

		sunlight = pow2(sunlight); // Fatten the shadow up to soften its penumbra (default hardware-filtered penumbra does not have a satisfying penumbra curve)
	#endif

	return sunlight;
}

vec3 CalculateShadedFragment(in vec3 diffuse, in Mask mask, in float torchLightmap, in float skyLightmap, in vec3 normal, in float smoothness, in vec4 ViewSpacePosition) {
	diffuse = pow(diffuse, vec3(2.2)); // Put diffuse into a linear color space (diffuse should not be previously gamma-adjusted)

	Shading shading;
	shading.normal = GetOrenNayarShading(ViewSpacePosition, normal, 1.0 - smoothness, mask);

	shading.sunlight  = shading.normal;
	shading.sunlight *= ComputeDirectSunlight(ViewSpacePosition, shading.normal);
	shading.sunlight = mix(shading.sunlight, 0.1, mask.metallic);

	shading.torchlight = 1.0 - pow(torchLightmap, 4.0);
	shading.torchlight = 1.0 / pow(shading.torchlight, 2.0) - 1.0;
	shading.torchlight = mix(shading.torchlight, 0, mask.metallic);

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
