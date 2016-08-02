float GetLambertianShading(in vec3 normal, in Mask mask) {
	float shading = max0(dot(normal, lightVector));
	      shading = shading * (1.0 - mask.grass       ) + mask.grass       ;
	      shading = shading * (1.0 - mask.leaves * 0.5) + mask.leaves * 0.5;
				
	return shading;
}

#include "/lib/Fragment/Reflectance_Models.fsh"

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

#define GetDiffuseShading(a, b, c, d) GetLambertianShading(b, d)
