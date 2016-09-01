float GetLambertianShading(vec3 normal, Mask mask) {
	float shading = max0(dot(normal, lightVector));
	      shading = shading * (1.0 - mask.grass       ) + mask.grass       ;
	      shading = shading * (1.0 - mask.leaves * 0.5) + mask.leaves * 0.5;
	
	return shading;
}

#define GetDiffuseShading(a, b, c, d) GetLambertianShading(b, d)
