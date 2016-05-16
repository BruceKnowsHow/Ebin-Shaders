
// Start of #include "/lib/ReflectanceModel.fsh"

/* Prerequisites:

// #include "/lib/Util.glsl"

*/


vec3 Fresnel(vec3 R0, float vdoth) {
	vec3 fresnel;
	
	vec3 Schlick = R0 + (vec3(1.0) - R0) * max0(pow(1.0 - vdoth, 5.0));
	
	vec3 SphericalGaussian = R0 + (vec3(1) - R0) * pow(2, (-5.55473 * vdoth - 6.98316) * vdoth);
	
	vec3 cookTorrance; //Phisically Accurate, handles metals better
	vec3 nFactor = (1.0 + sqrt(R0)) / (1.0 - sqrt(R0));
	vec3 gFactor = sqrt(pow(nFactor, vec3(2.0)) + pow(vdoth, 2.0) - 1.0);
	cookTorrance = 0.5 * pow((gFactor - vdoth) / (gFactor + vdoth), vec3(2.0)) * (1 + pow(((gFactor + vdoth) * vdoth - 1.0) / ((gFactor - vdoth) * vdoth + 1.0), vec3(2.0)));
	
	fresnel = cookTorrance;
	
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
	float phi = 2.0 * PI * epsilon.y;
	
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
	
	//geometry = ImplictGeom(viewVector, lightVector, normal);
	//geometry = NewmannGeom(viewVector, lightVector, normal);
	//geometry = cookTorranceGeom(viewVector, lightVector, halfVector, normal);
	//geometry = SmithGeom(viewVector, normal, alpha);
	geometry = GGXSmithGeom(lightVector, halfVector, alpha) * GGXSmithGeom(viewVector, halfVector, alpha); //Physical
	//geometry = SchlickBeckmannGeom(lightVector, halfVector, alpha) * SchlickBeckmannGeom(viewVector, halfVector, alpha); //Phisical
	
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
	
	//distribution = phongDistribution(halfVector, normal, alpha);
	//distribution = BeckmannDistribution(halfVector, normal, alpha);
	distribution = GGXDistribution(halfVector, normal, alpha);
	
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
vec3 CalculateSpecularHighlight(
	in vec3 lightVector,
	in vec3 normal,
	in vec3 fresnel,
	in vec3 viewVector,
	in float roughness) {
	
	roughness = pow2(roughness * 0.4);
	
	vec3 halfVector = normalize(lightVector + viewVector);
	
	float geometryFactor = CalculateGeometryDistribution(lightVector, viewVector, halfVector, normal, roughness);
	float microfacetDistribution = CalculateMicrofacetDistribution(halfVector, normal, roughness);
	
	float ldotn = max(0.01, dot(lightVector, normal));
	float vdotn = max(0.01, dot(viewVector, normal));
	
	return fresnel * geometryFactor * microfacetDistribution * ldotn / (4.0 * ldotn * vdotn);
}


// End of #include "/lib/ReflectanceModel.fsh"
