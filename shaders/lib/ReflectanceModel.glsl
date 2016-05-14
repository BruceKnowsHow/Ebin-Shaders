float cookTorranceGeom(in vec3 viewDirection, in vec3 lightDirection, in vec3 halfVector, in vec3 normal) {
  float hdotn = max(0, dot(halfVector, normal));
  float vdoth = max(0, dot(viewDirection, halfVector));
  float ndotv = max(0, dot(normal, viewDirection));
  float ndotl = max(0, dot(normal, lightDirection));
  
  // geometric attenuation
  float NH2 = 2.0 * hdotn;
  float g1 = (NH2 * ndotv) / vdoth;
  float g2 = (NH2 * ndotl) / vdoth;
  
  return min(1.0, min(g1, g2));
}

float GGXSmithGeom(in vec3 i, in vec3 normal, in float alpha) {
    float idotn = max(0, dot(normal, i));
    float idotn2 = pow(idotn, 2);

    return 2 * idotn / (idotn + sqrt(idotn2 + pow(alpha, 2) * (1 - idotn2)));
}

float SchlickBeckmannGeom(in vec3 i, in vec3 normal, in float alpha) {
  float k = sqrt((2 * pow(alpha, 2)) / 3.1415927);
  float idotn = max(0.0, dot(normal, i));
  
  return idotn / (idotn * (1 - k) + k);
}

/////////////////////////////////////////////////////////////////////////////

float GGXDistribution(in vec3 halfVector, in vec3 normal, in float alpha) {
    float alpha2 = pow(alpha, 2);
    float hdotn = max(0, dot(halfVector, normal));

    return alpha2 / (3.1415927 * pow(1 + pow(hdotn, 2) * (alpha2 - 1), 2));
}

float BeckmannDistribution(in vec3 halfVector, in vec3 normal, in float alpha) {
  float hdotn = max(0, dot(halfVector, normal));
  float alpha2 = pow(alpha, 2);
  
  return (1.0 / (3.1415927 * alpha2 * pow(hdotn, 3))) * pow(2.7182818, (pow(hdotn, 2) - 1.0) / (pow(hdotn, 2) * alpha2));
}

float phongDistribution(in vec3 halfVector, in vec3 normal, in float alpha) {
  float roughnessCoeff = 2 / pow(alpha, 2) - 2;
  float hdotn = max(0, dot(halfVector, normal));
  float Xp;
  
  if(hdotn <= 0) {
    Xp = 0;
  } else {
    Xp = 1;
  }
  
  return Xp * ((roughnessCoeff + 2) / (2 * 3.1415927)) * pow(hdotn, roughnessCoeff);
}

//lod falloff do it after

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
    float geometry = GGXSmithGeom(lightVector, halfVector, alpha) * GGXSmithGeom(viewVector, halfVector, alpha);
    
    //geometry = SchlickBeckmannGeom(lightVector, halfVector, alpha) * SchlickBeckmannGeom(viewVector, halfVector, alpha);
    //geometry = cookTorranceGeom(viewVector, lightVector, halfVector, normal);
    
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
    float distribution = GGXDistribution(halfVector, normal, alpha);
    
    //distribution = BeckmannDistribution(halfVector, normal, alpha);
    //distribution = phongDistribution(halfVector, normal, alpha);
    
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

    roughness = pow(roughness * 0.4, 2);

    vec3 halfVector = normalize(lightVector + viewVector);

    float geometryFactor = CalculateGeometryDistribution(lightVector, viewVector, halfVector, normal, roughness);
    float microfacetDistribution = CalculateMicrofacetDistribution(halfVector, normal, roughness);

    float ldotn = max(0.01, dot(lightVector, normal));
    float vdotn = max(0.01, dot(viewVector, normal));

    return fresnel * geometryFactor * microfacetDistribution * ldotn / (4 * ldotn * vdotn);
}
