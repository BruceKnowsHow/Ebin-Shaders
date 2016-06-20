float GetLambertianShading(in vec3 normal, in Mask mask) {
	float shading = max0(dot(normal, lightVector));
	      shading = shading * (1.0 - mask.grass       ) + mask.grass       ;
	      shading = shading * (1.0 - mask.leaves * 0.5) + mask.leaves * 0.5;
	
	return shading;
}

#ifdef PBR
float GetOrenNayarShading(in vec4 viewSpacePosition, in vec3 normal, in float roughness, in Mask mask) {
	vec3 eyeDir = normalize(viewSpacePosition.xyz);
	
	float NdotL = dot(normal, lightVector);
	float NdotV = dot(normal, eyeDir);
	
	float angleVN = acos(NdotV);
	float angleLN = acos(NdotL);
	
	float alpha = max(angleVN, angleLN);
	float beta  = min(angleVN, angleLN);
	float gamma = dot(eyeDir - normal * NdotV, lightVector - normal * NdotL);
	
	float roughnessSquared = pow2(roughness);
	
	float A = 1.0 - 0.50 * roughnessSquared / (roughnessSquared + 0.57);
	float B =       0.45 * roughnessSquared / (roughnessSquared + 0.09);
	float C = sin(alpha) * tan(beta);
	
	float shading = max0(NdotL) * (A + B * max0(gamma) * C);
	      shading = shading * (1.0 - mask.grass       ) + mask.grass       ;
	      shading = shading * (1.0 - mask.leaves * 0.5) + mask.leaves * 0.5;
	
	return shading;
}
#else
	#define GetOrenNayarShading(a, b, c, d) GetLambertianShading(b, d)
#endif
