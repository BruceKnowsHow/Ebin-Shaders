float GetLambertianShading(in vec3 normal, in Mask mask) {
	float shading = max0(dot(normal, lightVector));
	      shading = shading * (1.0 - mask.grass       ) + mask.grass       ;
	      shading = shading * (1.0 - mask.leaves * 0.5) + mask.leaves * 0.5;
				
	return shading;
}

float GetOrenNayarShading(in vec4 viewSpacePosition, in vec3 normal, in float roughness, in Mask mask) {
	if(roughness > 0.9) return GetLambertianShading(normal, mask);
	
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

float GetGotandaShading(in vec4 viewSpacePosition, in vec3 normal, in float roughness, in Mask mask) {
	if(roughness > 0.9) return GetLambertianShading(normal, mask);
	
	vec3 viewVector = -normalize(viewSpacePosition.xyz);
	vec3 halfVector = normalize(lightVector - viewVector);
	
	float VoH = dot(viewVector, halfVector); 
	float NoV = dot(normal, viewVector);
	float NoL = dot(normal, lightVector);
	
	cfloat F0 = 0.04;
	
	float alpha = pow2(roughness);
	float alpha2 = pow2(alpha);
	float VoL = VoH * VoH * 0.5 + 0.5;
	float Cosri = VoL - NoV * NoL;
	
	float alpha213 = alpha2 + 1.36053;
	float Fr = (1.0 - (0.542026 * alpha2 + 0.303573 * alpha) / alpha213) * (1.0 - pow(1.0 - NoV, 4 * alpha2) / alpha213) *
	          ((-0.733996 * alpha2 * alpha + 1.50912 * alpha2 - 1.16402 * alpha) * pow(1.0 - NoV, 1.0 + (1.0 / 39 * alpha2 * alpha2 + 1.0)) + 1.0);
	
	float Lm = (max0(1.0 - 2.0 * alpha) * (1.0 - pow(1.0 - NoL, 5.0)) + min(2.0 * alpha, 1.0)) * (1.0 - 0.5 * alpha * (NoL - 1.0)) * NoL;
	float Vd = (alpha2 / ((alpha2 + 0.09) * (1.31072 + 0.995584 * NoV))) * (1.0 - pow(1.0 - NoL, (1.0 - 0.3726732 * NoV * NoV) / (0.188566 + 0.38841 * NoV)));
	float Bp = Cosri < 0.0 ? 1.4 * NoV * NoL * Cosri : Cosri;
	float Lr = (21.0 / 20.0) * (1.0 - F0) * (Fr * Lm + Vd + Bp);
	
	float shading  = 2.5 / PI * Lr;
	      shading *= max0(NoL);
	      shading  = shading * (1.0 - mask.grass       ) + mask.grass       ;
	      shading  = shading * (1.0 - mask.leaves * 0.5) + mask.leaves * 0.5;
	
	return max0(shading);
}

float GetSubSurfaceDiffuse(in vec4 viewSpacePosition, in vec3 normal) { // This is a crude
	cfloat wrap = 0.6;
	cfloat scatterWidth = 0.4;
	
	vec3 viewVector = -normalize(viewSpacePosition.xyz);
	vec3 halfVector = normalize(lightVector - viewVector);
	
	float NdotH = dot(normal, halfVector);
	float NdotL = dot(normal, lightVector);
	float NdotLWrap = (NdotL + wrap) / (1.0 + wrap);
	
	float diffuse = max0(NdotLWrap);
	float scatter = smoothstep(0.0, scatterWidth, NdotLWrap) * smoothstep(scatterWidth * 2.0, scatterWidth, NdotLWrap);

	return diffuse + scatter;
}

#if defined PBR && ShaderStage > -1
	#if PBR_Diffuse == 1
		#define GetDiffuseShading(a, b, c, d) GetLambertianShading(b, d)
	#elif PBR_Diffuse == 2
		#define GetDiffuseShading(a, b, c, d) GetOrenNayarShading(a, b, c, d)
	#else
		#define GetDiffuseShading(a, b, c, d) GetGotandaShading(a, b, c, d)
	#endif
#else
	#define GetDiffuseShading(a, b, c, d) GetLambertianShading(b, d)
#endif
