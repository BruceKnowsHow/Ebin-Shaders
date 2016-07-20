float GetLambertianShading(in vec3 normal, in Mask mask) {
	float shading = max0(dot(normal, lightVector));
	      shading = shading * (1.0 - mask.grass       ) + mask.grass       ;
	      shading = shading * (1.0 - mask.leaves * 0.5) + mask.leaves * 0.5;
	
	return shading;
}

#if defined PBR && ShaderStage > -1
float GetOrenNayarShading(in vec4 viewSpacePosition, in vec3 normal, in float roughness, in Mask mask) {
	/* *vec3 eyeDir = normalize(viewSpacePosition.xyz);
	
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
	      shading = shading * (1.0 - mask.leaves * 0.5) + mask.leaves * 0.5; /* */
	
	vec3 viewVector = -normalize(viewSpacePosition.xyz);
	vec3 halfVector = normalize(lightVector - viewVector);
	
	float VoH = dot(viewVector, halfVector); 
	float NoV = dot(normal, viewVector);
	float NoL = dot(normal, lightVector);
				
	float alpha = pow2(roughness);
	float alpha2 = pow2(alpha);
	float VoL = VoH * VoH;
	float Cosri = VoL - NoV * NoL;
	
	float C1 = 1.0 - 0.5 * alpha2 / (alpha2 + 0.33);
	float C2 = 0.45 * alpha2 / (alpha2 + 0.09) * Cosri * (Cosri >= 0.0 ? 1.0 / max(NoL, NoV) : 1.0);
	
	float shading = 2.5 / PI * (C1 + C2) * (1.0 + roughness * 0.5);
	      shading *= max0(NoL);
	      shading = shading * (1.0 - mask.grass       ) + mask.grass       ;
	      shading = shading * (1.0 - mask.leaves * 0.5) + mask.leaves * 0.5;
	
	return shading;
}
#else
	#define GetOrenNayarShading(a, b, c, d) GetLambertianShading(b, d)
#endif
