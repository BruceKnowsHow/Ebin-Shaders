float noise(vec2 coord) {
    return fract(sin(dot(coord, vec2(12.9898, 4.1414))) * 43758.5453);
}

float radicalInverse_VdC(uint bits) {
     bits = (bits << 16u) | (bits >> 16u);
     bits = ((bits & 0x55555555u) << 1u) | ((bits & 0xAAAAAAAAu) >> 1u);
     bits = ((bits & 0x33333333u) << 2u) | ((bits & 0xCCCCCCCCu) >> 2u);
     bits = ((bits & 0x0F0F0F0Fu) << 4u) | ((bits & 0xF0F0F0F0u) >> 4u);
     bits = ((bits & 0x00FF00FFu) << 8u) | ((bits & 0xFF00FF00u) >> 8u);
     return float(bits) * 2.3283064365386963e-10; // / 0x100000000
 }

vec2 Hammersley(uint i, uint N) {
  return vec2(float(i) / float(N), radicalInverse_VdC(i));
}


float randAngle() {
	uint x = uint(gl_FragCoord.x);
	uint y = uint(gl_FragCoord.y);

	return (30u * x ^ y + 10u * x * y);
}

float F0Calc(float F0, float metallic) {
	if(metallic > 0.01) F0 = metallic;
	return F0 = clamp(F0, 0.02, 0.99);
}

/////////////////////////////////////////////////////////////////////////////
float diffuseFresnel(float F0, float NoL, float NoV) {	
	return clamp01((21.0 / 20.0) * (1.0 - F0) * (1.0 - pow(1.0 - NoL, 5.0)) * (1.0 - pow(1.0 - NoV, 5.0)));
}


float lambertDiffuse(vec4 viewSpacePosition, vec3 normal, float roughness) {
	return 2.0 / PI * dot(normal, lightVector);
}

float GetBurleyDiffuse(vec4 viewSpacePosition, vec3 normal, float roughness) {
	vec3 viewVector = -normalize(viewSpacePosition.xyz);
	vec3 halfVector = normalize(viewVector + lightVector);
	
	float VoH = dot(viewVector, halfVector); 
	float NoV = dot(normal, viewVector);
	float NoL = dot(normal, lightVector);
	
	float FD90 = 0.5 + 2.0 * VoH * VoH * roughness;
	float FdV = 1.0 + (FD90 - 1.0) * pow(1.0 - NoV, 5.0);
	float FdL = 1.0 + (FD90 - 1.0) * pow(1.0 - NoL, 5.0);
	
	return (1.0 / PI) * FdV * FdL;
}

float GetOrenNayarDiffuse(vec4 viewSpacePosition, vec3 normal, float roughness, float F0) {
	vec3 viewVector = -normalize(viewSpacePosition.xyz);
	vec3 halfVector = normalize(lightVector + viewVector);
	cfloat albedo = 3.0;
	
	float VoH = dot(viewVector, halfVector); 
	float NoV = dot(normal, viewVector);
	float NoL = dot(normal, lightVector);
	float VoL = dot(viewVector, lightVector);
	
	float alpha = pow2(roughness);
	float alpha2 = pow2(alpha);
	float Cosri = VoL - NoV * NoL;
	float CosriT = Cosri >= 0.0 ? min(1.0, NoL / NoV) : 1.0;
	
	float Fdiff = 1.0;
	
	#if PBR_Diffuse == 4
		Fdiff = diffuseFresnel(F0, NoL, NoV);
	#endif
	
	float C1 = (1.0 - 0.5 * (alpha2 / (alpha2 + 0.33)) + 0.17 * albedo * (alpha2 / (alpha2 + 0.13))) / PI;
	float C2 = 0.45 * (alpha2 / (alpha2 + 0.09)) / PI;

	return albedo * (1.0 - F0) * NoL * (Fdiff * C1 + C2 * (Cosri / CosriT));
}

float GetGotandaDiffuse(vec4 viewSpacePosition, vec3 normal, float roughness, float F0) {
	vec3 viewVector = -normalize(viewSpacePosition.xyz);
	vec3 halfVector = normalize(viewVector + lightVector);
	
	float VoH = dot(viewVector, halfVector); 
	float NoV = dot(normal, viewVector);
	float NoL = dot(normal, lightVector);
	float VoL = dot(viewVector, lightVector);
	
	float alpha = pow2(roughness);
	float alpha2 = pow2(alpha);
	float Cosri = VoL - NoV * NoL;
	
	float alpha213 = alpha2 + 1.36053;
	float Fr = (1.0 - (0.542026 * alpha2 + 0.303573 * alpha) / alpha213) * (1.0 - pow(1.0 - NoV, 5.0 - 4.0 * alpha2) / alpha213) *
	          ((-0.733996 * alpha2 * alpha + 1.50912 * alpha2 - 1.16402 * alpha) * pow(1.0 - NoV, 1.0 + (1.0 / (39.0 * alpha2 * alpha2 + 1.0))) + 1.0);
	
	float Lm = (max0(1.0 - 2.0 * alpha) * (1.0 - pow(1.0 - NoL, 5.0)) + min(2.0 * alpha, 1.0)) * ((1.0 - 0.5 * alpha) * NoL + 0.5 * alpha * pow2(NoL));
	float Vd = (alpha2 / ((alpha2 + 0.09) * (1.31072 + 0.995584 * NoV))) * (1.0 - pow(1.0 - NoL, (1.0 - 0.3726732 * NoV * NoV) / (0.188566 + 0.38841 * NoV)));
	float Bp = Cosri < 0.0 ? 1.4 * NoV * NoL * Cosri : Cosri;
	float Lr = (21.0 / (20.0 * PI)) * (1.0 - F0) * (Fr * Lm + Vd * Bp);

	return 2.0 * Lr;
}

float GetGGXSubsurfaceDiffuse(vec4 viewSpacePosition, vec3 normal, float roughness) {
	cfloat wrap = 0.5;
	
	vec3 viewVector = normalize(viewSpacePosition.xyz);
	float NoL = clamp01((dot(normal, lightVector) + wrap) / pow2(1.0 + wrap));
	float VoL = clamp01(dot(viewVector, lightVector));
	
	float alpha2 = pow2(roughness);
	float distrobution = (VoL * alpha2 - VoL) * VoL + 1.0;
	float GGX = (alpha2 / PI) / pow2(distrobution);
	
	return NoL * GGX * 2.0;
}

float diffuse(float F0, vec4 viewSpacePosition, vec3 normal, float roughness) {
float diffuse;
	#if PBR_Diffuse == 1
		diffuse = lambertDiffuse(viewSpacePosition, normal, roughness);
	#elif PBR_Diffuse == 2
		diffuse = GetBurleyDiffuse(viewSpacePosition, normal, roughness);
	#elif PBR_Diffuse == 3 || 4
		diffuse = GetOrenNayarDiffuse(viewSpacePosition, normal, roughness, F0);
	#else
		diffuse = GetGotandaDiffuse(viewSpacePosition, normal, roughness, F0);
	#endif
	
	return diffuse;
}

/////////////////////////////////////////////////////////////////////////////

float schlickFresnel(float VoH, float F0) {
	return F0 + (1.0 - F0) * max0(pow(1.0 - VoH, 5.0));
}

float schlickGaussianFresnel(float VoH, float F0) {
	return F0 + (1 - F0) * pow(2, (-5.55473 * VoH - 6.98316) * VoH);
}

float cookTorranceFresnel(float VoH, float F0) {
	float nFactor = (1.0 + sqrt(F0)) / (1.0 - sqrt(F0));
	float gFactor = sqrt(pow2(nFactor) + pow2(VoH) - 1.0);
	
	float C1 = 0.5 * pow((gFactor - VoH) / (gFactor + VoH), 2.0);
	float C2 = (1.0 + pow(((gFactor + VoH) * VoH - 1.0) / ((gFactor - VoH) * VoH + 1.0), 2.0));
	
	return C1 * C2;
}

float gotandaFresnel(float VoH, float F0) {
	float sF0 = sqrt(F0);
	float alpha = sqrt(1.0 - (pow2(sF0 - 1.0) * (1.0 - pow2(VoH))) / pow2(sF0 + 1.0));
	
	float C1 = pow2(((sF0 + 1.0) * VoH + (sF0 - 1.0) * alpha) / (((sF0 + 1.0) * VoH - (sF0 - 1.0) * alpha)));
	float C2 = pow2(((sF0 - 1.0) * VoH + (sF0 + 1.0) * alpha) / (((sF0 - 1.0) * VoH - (sF0 + 1.0) * alpha)));
	
	return 0.5 * (C1 + C2);
}

float Fresnel(float F0, float VoH) {
	float fresnel;
	
	#if FRESNEL == 1
		fresnel = schlickFresnel(VoH, F0);
		
	#elif FRESNEL == 2
		fresnel = schlickGaussianFresnel(VoH, F0);
		
	#elif FRESNEL == 3
		fresnel = cookTorranceFresnel(VoH, F0);
		
	#else //Real fresnel, no approximations made here.
		fresnel = gotandaFresnel(VoH, F0);
		
	#endif

  return fresnel;
}

/////////////////////////////////////////////////////////////////////////////

float ImplictGeom(float NoL, float NoV) {
	return NoL * NoV;
}

float NewmannGeom(float NoL, float NoV) {
	return (NoL * NoV) / max(NoL, NoV);
}

float SmithGeom(float NoV, float alpha) {
	float alphaCoeff = sqrt((2.0 * pow2(alpha)) / PI);
	
	return NoV / (NoV * (1.0 - alphaCoeff) + alphaCoeff);
}

float cookTorranceGeom(float NoL, float NoV, float NoH, float VoH) {
	// geometric attenuation
	float NH2 =  2.0 * NoH;
	float g1  = (NH2 * NoV) / VoH;
	float g2  = (NH2 * NoL) / VoH;
	
	return min1(min(g1, g2));
}

float GGXSmithGeom(float NoX, float alpha) {
	float numerator = 2.0 * NoX;
	float NoX2 = pow2(NoX);
	float alpha2 = pow2(alpha);
	float denominator = NoX + sqrt(NoX2 + alpha2 * (1.0 - NoX2));
	
	return numerator / denominator;
}

float SchlickBeckmannGeom(float NoX, float alpha) {
	float k = pow2(alpha) * PI;
	return NoX / (NoX * (1.0 - k) + k);
}

/////////////////////////////////////////////////////////////////////////////

float phongDistribution(float NoH, float alpha) {
	float alpha2 = pow2(alpha);
	float alphap = (2.0 / alpha2) - 2.0;
	
	return clamp01(NoH) * ((alphap + 2.0) / pow2(PI)) * pow(NoH, alphap);
}

float BeckmannDistribution(float NoH, float alpha) {
	float alpha2 = pow2(alpha);
	float NoH2 = pow2(NoH);
	
	return exp((NoH2 - 1.0) / (NoH2 * alpha2)) / (PI * alpha2 * NoH * NoH2);
}

float GGXDistribution(float NoH, float alpha) {
	float alpha2 = pow2(alpha);
	
	return alpha2 / (PI * pow2(1.0 + pow2(NoH) * (alpha2 - 1.0)));
}

/////////////////////////////////////////////////////////////////////////////
vec3 MakeSample(float Theta, float Phi) {
  Phi += randAngle();
  float SineTheta = sin(Theta);

  float x = cos(Phi) * SineTheta;
  float y = sin(Phi) * SineTheta;
  float z = cos(Theta);

  return vec3(x, y, z);
}

vec3 phongSkew(vec2 epsilon, float roughness) {
  float ap = (2.0 / roughness);
  float Theta = acos(pow(epsilon.x, 2.0 / ap)) / (PI * PI * 4.0);
  float Phi = PI * 2.0 * epsilon.y;
  return MakeSample(Theta, Phi);
}

vec3 beckmannSkew(vec2 epsilon, float roughness) {
  float a = roughness * roughness;
  float Theta = atan(sqrt(-a * log(1.0 - epsilon.x)));
  float Phi = PI * 2.0 * epsilon.y;
  return MakeSample(Theta, Phi);
}

vec3 ggxSkew(vec2 epsilon, float roughness) {
  float a = roughness * roughness;
  float Theta = atan(sqrt((a * epsilon.x) / (1.0 - epsilon.x)));
  float Phi = PI * 2.0 * epsilon.y;
  return MakeSample(Theta, Phi);
}

vec3 skew(vec2 epsilon, float roughness) {
	vec3 skew;
		
	#if PBR_SKEW == 1
		skew = phongSkew(epsilon, roughness);
	#elif PBR_SKEW == 2
		skew = beckmannSkew(epsilon, roughness);
	#elif PBR_SKEW == 3
		skew = ggxSkew(epsilon, roughness);
	#endif
		
	return skew;	
}

/*!
 * \brief Calculates the geometry distribution given the given parameters
 *
 * \param lightVector The normalized, view-space vector from the light to the current fragment
 * \param viewVector The normalized, view-space vector from the camera to the current fragment
 * \param halfVector The vector halfway between the normal and view vector
 *
 * \return The geometry distribution of the given fragment
 */
float CalculateGeometryDistribution(float NoL, float NoV, float NoH, float VoH, float alpha) {
	float geometry;
	
	#if PBR_GEOMETRY_MODEL == 1
		geometry = ImplictGeom(NoL, NoV);
		
	#elif PBR_GEOMETRY_MODEL == 2
		geometry = NewmannGeom(NoL, NoV);
		
	#elif PBR_GEOMETRY_MODEL == 3
		geometry = cookTorranceGeom(NoL, NoV, NoH, VoH);
	
	#elif PBR_GEOMETRY_MODEL == 4
		geometry = SmithGeom(NoV, alpha);
	
	#elif PBR_GEOMETRY_MODEL == 5
		geometry = GGXSmithGeom(NoL, alpha) * GGXSmithGeom(NoV, alpha); //Physical
		
	#elif PBR_GEOMETRY_MODEL == 6
		geometry = SchlickBeckmannGeom(NoL, alpha) * SchlickBeckmannGeom(NoV, alpha); //Phisical
		
	#endif
	
	return clamp(geometry, -1.0, 1.0);
}

/*!
 * \brief Calculates the nicrofacet distribution for the current fragment
 *
 * \param halfVector The half vector for the current fragment
 * \param normal The viewspace normal of the current fragment
 *
 * \return The microfacet distribution for the current fragment
 */
float CalculateMicrofacetDistribution(float NoH, float alpha) {
	float distribution;
		
	#if PBR_DISTROBUTION_MODEL == 1	
		distribution = clamp01(phongDistribution(NoH, alpha));
		
	#elif PBR_DISTROBUTION_MODEL == 2
		distribution = BeckmannDistribution(NoH, alpha);
		
	#elif PBR_DISTROBUTION_MODEL == 3
		distribution = GGXDistribution(NoH, alpha);
		
	#endif
	
	return clamp(distribution, -10.0, 10.0);
}

float CalculateNormalizationFactor(float NoL, float NoV, float alpha) {
	return (4.0 * NoL * NoV);
}

/*!
 * \brief Calculates a specular highlight for a given light
 *
 * \param lightVector The normalized view space vector from the fragment being shaded to the light
 * \param normal The normalized view space normal of the fragment being shaded
 * \param fresnel The fresnel foctor for this fragment
 * \param viewVector The normalized vector from the fragment to the camera being shaded, expressed view space
 * \param roughness The roughness of the fragment
 *
 * \return The color of the specular highlight at the current fragment
 */
float specularBRDF(
	vec3 inVector,
	vec3 normal,
	float F0,
	vec3 viewVector,
	float alpha,
  out float NoH) {
	
	vec3 halfVector = (viewVector + inVector) / length(viewVector + inVector);
	
	float NoL = dot(normal, inVector);
	float NoV = dot(normal, viewVector);
	NoH = dot(normal, halfVector);
	float VoH = dot(viewVector, halfVector);
	
	float fresnel = Fresnel(F0, VoH);
	float geometryFactor = CalculateGeometryDistribution(NoL, NoV, NoH, VoH, alpha);
	float microfacetDistribution = CalculateMicrofacetDistribution(NoH, alpha);
	float normalizationFactor = CalculateNormalizationFactor(NoL, NoV, alpha);
	show(microfacetDistribution - 10);
	return fresnel * geometryFactor * microfacetDistribution * max0(NoL) / normalizationFactor;
}

#if ShaderStage == 2
  float computeLod(float NoH, uint numSamples, float alpha) {
    float dist = CalculateMicrofacetDistribution(NoH, pow2(alpha));
    return 0.25 * (log2(float(viewWidth * viewHeight) / numSamples) - log2(dist));
  }
#endif

vec3 BlendMaterial(vec3 color, vec3 specular, float F0) {
  float scRange = smoothstep(0.25, 0.45, F0);
  vec3  dielectric = color + specular;
  vec3  metal = specular * color;
  
  return mix(dielectric, metal, scRange);
}
