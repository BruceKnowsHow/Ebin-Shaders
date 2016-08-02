// Noise Functions

vec2 Hammersley(uint i, uint N) {
	return vec2(float(i) / float(N), float(bitfieldReverse(i)) * 2.3283064365386963e-10);
}

float randAngle() {
	uint x = uint(gl_FragCoord.x);
	uint y = uint(gl_FragCoord.y);
	
	return float(30u * pow(x, y) + 10u * x * y);
}

float R0Calc(in float R0, in float metallic) {
	if(metallic > 0.01) R0 = metallic;
	return R0 = clamp(R0, 0.02, 0.99);
}

/////////////////////////////////////////////////////////////////////////////

float lambertDiffuse(in vec4 viewSpacePosition, in vec3 normal, in float roughness) {
	return 2.0 / PI * dot(normal, lightVector);
}

float GetBurleyDiffuse(in vec4 viewSpacePosition, in vec3 normal, in float roughness) {
	vec3 viewVector = normalize(viewSpacePosition.xyz);
	vec3 halfVector = normalize(lightVector - viewVector);
	
	float VoH = dot(viewVector, halfVector); 
	float NoV = dot(normal, viewVector);
	float NoL = dot(normal, lightVector);
	
	float FD90 = 0.5 + 2.0 * VoH * VoH * roughness;
	float FdV = 1.0 + (FD90 - 1.0) * pow(1.0 - NoV, 5.0);
	float FdL = 1.0 + (FD90 - 1.0) * pow(1.0 - NoL, 5.0);
	
	return (1.0 / PI) * FdV * FdL;
}

float GetOrenNayarDiffuse(in vec4 viewSpacePosition, in vec3 normal, in float roughness, in float R0) {
	vec3 viewVector = normalize(viewSpacePosition.xyz);
	vec3 halfVector = normalize(lightVector + viewVector);
	
	float VoH = dot(viewVector, halfVector); 
	float NoV = dot(normal, viewVector);
	float NoL = dot(normal, lightVector);
	float VoL = dot(viewVector, lightVector);
	
	float alpha = pow2(roughness);
	float alpha2 = pow2(alpha);
	float Cosri = VoL - NoV * NoL;
	
	float C1 = NoL * (1.0 - R0) * (1.0 - 0.5 * alpha2 / (alpha2 + 0.65));
	float C2 = 0.45 * alpha2 / (alpha2 + 0.09) * Cosri * (Cosri >= 0.0 ? clamp01(1.0 / max(NoL, NoV)) : 1.0);

	return 2.0 / PI * (C1 + C2) * (1.0 + roughness * 0.5);
}

float GetGotandaDiffuse(in vec4 viewSpacePosition, in vec3 normal, in float roughness, in float R0) {
	vec3 viewVector = normalize(viewSpacePosition.xyz);
	vec3 halfVector = normalize(lightVector + viewVector);
	
	float VoH = dot(viewVector, halfVector); 
	float NoV = dot(normal, viewVector);
	float NoL = dot(normal, lightVector);
	float VoL = dot(viewVector, lightVector);
	
	float alpha = pow2(roughness);
	float alpha2 = pow2(alpha);
	float Cosri = VoL - NoV * NoL;
	
	float alpha213 = alpha2 + 1.36053;
	float Fr = (1.0 - (0.542026 * alpha2 + 0.303573 * alpha) / alpha213) * (1.0 - pow(1.0 - NoV, 5.0 - 4.0 * alpha2) / alpha213) *
	          ((-0.733996 * alpha2 * alpha + 1.50912 * alpha2 - 1.16402 * alpha) * pow(1.0 - NoV, 1.0 + (1.0 / 39 * alpha2 * alpha2 + 1.0)) + 1.0);
	
	float Lm = (max0(1.0 - 2.0 * alpha) * (1.0 - pow(1.0 - NoL, 5.0)) + min(2.0 * alpha, 1.0)) * ((1.0 - 0.5 * alpha) * NoL + 0.5 * alpha * pow2(NoL));
	float Vd = (alpha2 / ((alpha2 + 0.09) * (1.31072 + 0.995584 * NoV))) * (1.0 - pow(1.0 - NoL, (1 - 0.3726732 * NoV * NoV) / (0.188566 + 0.38841 * NoV)));
	float Bp = Cosri < 0.0 ? 1.4 * NoV * NoL * Cosri : Cosri;
	float Lr = (21.0 / 20.0 * PI) * (1.0 - R0) * (Fr * Lm + Vd * Bp);

	return 1.0 / PI * Lr;
}

float diffuse(in float R0, in vec4 viewSpacePosition, in vec3 normal, in float roughness) {
float diffuse;
	#if PBR_Diffuse == 1
		diffuse = lambertDiffuse(viewSpacePosition, normal, roughness);
	#elif PBR_Diffuse == 2
		diffuse = GetBurleyDiffuse(viewSpacePosition, normal, roughness);
	#elif PBR_Diffuse ==3
		diffuse = GetOrenNayarDiffuse(viewSpacePosition, normal, roughness, R0);
	#else
		diffuse = GetGotandaDiffuse(viewSpacePosition, normal, roughness, R0);
	#endif
	
	return diffuse;
}

/////////////////////////////////////////////////////////////////////////////

float Fresnel(float R0, float vdoth, in float metallic) {
	float fresnel;
	
	#if FRESNEL == 1
		fresnel = R0 + (1.0 - R0) * max0(pow(1.0 - vdoth, 5.0));
		
	#elif FRESNEL == 2
		fresnel = R0 + (1 - R0) * pow(2, (-5.55473 * vdoth - 6.98316) * vdoth);
		
	#elif FRESNEL == 3
		float nFactor = (1.0 + sqrt(R0)) / (1.0 - sqrt(R0));
		float gFactor = sqrt(pow2(nFactor) + pow2(vdoth) - 1.0);
		fresnel = 0.5 * pow((gFactor - vdoth) / (gFactor + vdoth), 2.0) * (1.0 + pow(((gFactor + vdoth) * vdoth - 1.0) / ((gFactor - vdoth) * vdoth + 1.0), 2.0));
	#else //Real fresnel, no approximations made here.
		float sF0 = sqrt(R0);
		float alpha = sqrt(1.0 - (pow2(sF0 - 1.0) * (1.0 - pow2(vdoth))) / pow2(sF0 + 1.0));
		
		float C1 = pow2(((sF0 + 1.0) * vdoth + (sF0 - 1.0) * alpha) / (((sF0 + 1.0) * vdoth - (sF0 - 1.0) * alpha)));
		float C2 = pow2(((sF0 - 1.0) * vdoth + (sF0 + 1.0) * alpha) / (((sF0 - 1.0) * vdoth - (sF0 + 1.0) * alpha)));
		
		fresnel = 0.5 * (C1 + C2);
	#endif

  return fresnel;
}

float ImplictGeom(in vec3 viewDirection, in vec3 lightDirection, in vec3 normal) {
	float ndotl = max0(dot(normal, lightDirection));
	float ndotv = max0(dot(normal, viewDirection));
	
	return ndotl * ndotv;
}

float NewmannGeom(in vec3 viewDirection, in vec3 lightDirection, in vec3 normal) {
	float ndotl = max0(dot(normal, lightDirection));
	float ndotv = max0(dot(normal, viewDirection));
	
	return (ndotl * ndotv) / max(ndotl, ndotv);
}

float SmithGeom(in vec3 viewDirection, in vec3 normal, in float alpha) {
	float ndotv = max0(dot(normal, viewDirection));
	float alphaCoeff = sqrt((2.0 * pow2(alpha)) / PI);
	
	return ndotv / (ndotv * (1.0 - alphaCoeff) + alphaCoeff);
}

float cookTorranceGeom(in vec3 viewDirection, in vec3 lightDirection, in vec3 halfVector, in vec3 normal) {
	float hdotn = max0(dot(halfVector, normal));
	float vdoth = max0(dot(viewDirection, halfVector));
	float ndotv = max0(dot(normal, viewDirection));
	float ndotl = max0(dot(normal, lightDirection));
	
	// geometric attenuation
	float NH2 =  2.0 * hdotn;
	float g1  = (NH2 * ndotv) / vdoth;
	float g2  = (NH2 * ndotl) / vdoth;
	
	return min1(min(g1, g2));
}

float GGXSmithGeom(in vec3 i, in vec3 normal, in float alpha) {
	float idotn = max0(dot(normal, i));
	float idotn2 = pow2(idotn);
	
	return 2.0 * idotn / (idotn + sqrt(idotn2 + pow(alpha, 2.0) * (1 - idotn2)));
}

float SchlickBeckmannGeom(in vec3 i, in vec3 normal, in float alpha) {
	float k = sqrt((2.0 * pow2(alpha)) / PI);
	float idotn = max0(dot(normal, i));
	
	return idotn / (idotn * (1 - k) + k);
}

/////////////////////////////////////////////////////////////////////////////

float GGXDistribution(in vec3 halfVector, in vec3 normal, in float alpha) {
	float alpha2 = pow2(alpha);
	float hdotn = max0(dot(halfVector, normal));
	
	return alpha2 / (PI * pow2(1.0 + pow2(hdotn) * (alpha2 - 1.0)));
}

float BeckmannDistribution(in vec3 halfVector, in vec3 normal, in float alpha) {
	float hdotn = max0(dot(halfVector, normal));
	float alpha2 = pow2(alpha);
	
	return (1.0 / (PI * alpha2 * pow(hdotn, 3.0))) * exp((pow2(hdotn) - 1.0) / (pow2(hdotn) * alpha2));
}

float phongDistribution(in vec3 halfVector, in vec3 normal, in float alpha) {
	float roughnessCoeff = 2.0 / pow2(alpha) - 2.0;
	float hdotn = max0(dot(halfVector, normal));
	float Xp = (hdotn <= 0.0 ? 0.0 : 1.0);
	
	return Xp * ((roughnessCoeff + 2.0) / (2.0 * PI)) * pow(hdotn, roughnessCoeff);
}

vec3 phongSkew(in vec2 epsilon, in float roughness) {
	// Uses the Phong sample skewing Functions
	float Ap = (2.0 / pow2(roughness)) - 2.0;
	float theta = acos(pow(epsilon.x, (2.0 / Ap + 2.0)));
	float phi = 2.0 * PI * epsilon.y + randAngle();
	
	float sin_theta = sin(theta);
	
	float x = cos(phi) * sin_theta;
	float y = sin(phi) * sin_theta;
	float z = cos(theta);
	
	return vec3(x, y, z);
}

vec3 beckmannSkew(in vec2 epsilon, in float roughness) {
	// Uses the Beckman sample skewing Functions
	float theta = atan(sqrt(-pow2(roughness) * log(1.0 - epsilon.x)));
	float phi = 2.0 * PI * epsilon.y;
	
	float sin_theta = sin(theta);
	
	float x = cos(phi) * sin_theta;
	float y = sin(phi) * sin_theta;
	float z = cos(theta);
	
	return vec3(x, y, z);
}

vec3 ggxSkew(in vec2 epsilon, in float roughness) {
	// Uses the GGX sample skewing Functions
	float theta = atan(sqrt(roughness * roughness * epsilon.x / (1.0 - epsilon.x)));
	float phi = 2.0 * PI * epsilon.y;
	
	float sin_theta = sin(theta);
	
	float x = cos(phi) * sin_theta;
	float y = sin(phi) * sin_theta;
	float z = cos(theta);
	
	return vec3(x, y, z);
}

vec3 skew(in vec2 epsilon, in float roughness) {
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
float CalculateGeometryDistribution(in vec3 lightVector, in vec3 viewVector, in vec3 halfVector, in vec3 normal, in float alpha) {
	float geometry;
	
	#if PBR_GEOMETRY_MODEL == 1
		geometry = ImplictGeom(viewVector, lightVector, normal);
		
	#elif PBR_GEOMETRY_MODEL == 2
		geometry = NewmannGeom(viewVector, lightVector, normal);
		
	#elif PBR_GEOMETRY_MODEL == 3
		geometry = cookTorranceGeom(viewVector, lightVector, halfVector, normal);
	
	#elif PBR_GEOMETRY_MODEL == 4
		geometry = SmithGeom(viewVector, normal, alpha);
	
	#elif PBR_GEOMETRY_MODEL == 5
		geometry = GGXSmithGeom(lightVector, halfVector, alpha) * GGXSmithGeom(viewVector, halfVector, alpha); //Physical
		
	#elif PBR_GEOMETRY_MODEL == 6
		geometry = SchlickBeckmannGeom(lightVector, halfVector, alpha) * SchlickBeckmannGeom(viewVector, halfVector, alpha); //Phisical
		
	#endif
	
	return geometry;
}

/*!
 * \brief Calculates the nicrofacet distribution for the current fragment
 *
 * \param halfVector The half vector for the current fragment
 * \param normal The viewspace normal of the current fragment
 *
 * \return The microfacet distribution for the current fragment
 */
float CalculateMicrofacetDistribution(in vec3 halfVector, in vec3 normal, in float alpha) {
	float distribution;
		
	#if PBR_DISTROBUTION_MODEL == 1	
		distribution = phongDistribution(halfVector, normal, alpha);
		
	#elif PBR_DISTROBUTION_MODEL == 2
		distribution = BeckmannDistribution(halfVector, normal, alpha);
		
	#elif PBR_DISTROBUTION_MODEL == 3
		distribution = GGXDistribution(halfVector, normal, alpha);
		
	#endif
	
	return distribution;
}

/*!
 * \brief Calculates a specular highlight for a given light
 *
 * \param lightVector The normalized view space vector from the fragment being shaded to the light
 * \param normal The normalized view space normal of the fragment being shaded
 * \param fresnel The fresnel foctor for this fragment
 * \param viewVector The normalized vector from the fragment to the camera being shaded, expressed in view space
 * \param roughness The roughness of the fragment
 *
 * \return The color of the specular highlight at the current fragment
 */
float CalculateSpecularHighlight(
	in vec3 lightVector,
	in vec3 normal,
	in float fresnel,
	in vec3 viewVector,
	in float roughness) {
	
	roughness = pow2(roughness * 0.5);
	roughness = clamp01(roughness);
	
	vec3 halfVector = normalize(lightVector + viewVector);
	
	float geometryFactor = CalculateGeometryDistribution(lightVector, viewVector, halfVector, normal, roughness);
	float microfacetDistribution = CalculateMicrofacetDistribution(halfVector, normal, roughness);
	
	float ldotn = max(0.01, dot(lightVector, normal));
	float vdotn = max(0.01, dot(viewVector, normal));
	
	return fresnel * geometryFactor * microfacetDistribution * ldotn / (4.0 * ldotn * vdotn);
}

vec3 BlendMaterial(in vec3 color, in vec3 specular, in float R0, in float smoothness) {
  float scRange = smoothstep(0.25, 0.45, R0);
  vec3  dielectric = color + specular * smoothness * 0.5;
  vec3  metal = specular * color * 0.6;

  return mix(dielectric, metal, scRange);
}
