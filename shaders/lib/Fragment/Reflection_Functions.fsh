#ifndef PBR
void ComputeReflectedLight(inout vec3 color, vec4 viewSpacePosition, vec3 normal, float smoothness, float skyLightmap, Mask mask) {
	if (isEyeInWater == 1) return;
	
	vec3  rayDirection  = normalize(reflect(viewSpacePosition.xyz, normal));
	float firstStepSize = mix(1.0, 30.0, pow2(length((gbufferModelViewInverse * viewSpacePosition).xz) / 144.0));
	vec3  reflectedCoord;
	vec4  reflectedViewSpacePosition;
	vec3  reflection;
	float VoH;
	
	float roughness = 1.0 - smoothness;
	
	vec3 viewVector = -normalize(viewSpacePosition.xyz);
	vec3 halfVector = normalize(lightVector - viewVector);
	
	float vdotn   = clamp01(dot(viewVector, normal));
	float vdoth   = clamp01(dot(viewVector, halfVector));
	
	cfloat F0 = 0.15; //To be replaced with metalloic
	
	float lightFresnel = Fresnel(F0, vdoth);
	
	vec3 alpha = vec3(lightFresnel * smoothness) * 0.25;
	
	if (length(alpha) < 0.005) return;
	
	
	float sunlight = ComputeShadows(viewSpacePosition, 1.0);
	
	vec3 reflectedSky  = CalculateSky(vec4(reflect(viewSpacePosition.xyz, normal), 1.0), 1.0, true).rgb;
	     reflectedSky *= 1.0;
	
	float reflectedSunspot = specularBRDF(lightVector, normal, F0, -normalize(viewSpacePosition.xyz), roughness, VoH) * sunlight;
	
	vec3 offscreen = reflectedSky + reflectedSunspot * sunlightColor * 10.0;
	
	if (!ComputeRaytracedIntersection(viewSpacePosition.xyz, rayDirection, firstStepSize, 1.55, 30, 1, reflectedCoord, reflectedViewSpacePosition))
		reflection = offscreen;
	else {
		reflection = GetColor(reflectedCoord.st);
		
		reflection = mix(reflection, reflectedSky, CalculateFogFactor(reflectedViewSpacePosition, FOG_POWER));
		
		#ifdef REFLECTION_EDGE_FALLOFF
			float angleCoeff = clamp(pow(dot(vec3(0.0, 0.0, 1.0), normal) + 0.15, 0.25) * 2.0, 0.0, 1.0) * 0.2 + 0.8;
			float dist       = length8(abs(reflectedCoord.xy - vec2(0.5)));
			float edge       = clamp(1.0 - pow2(dist * 2.0 * angleCoeff), 0.0, 1.0);
			reflection       = mix(reflection, reflectedSky, pow(1.0 - edge, 10.0));
		#endif
	}
	
	reflection = max(reflection, 0.0);
	
	color = mix(color, reflection, alpha);
}

#else

void ComputeReflectedLight(inout vec3 color, vec4 viewSpacePosition, vec3 normal, float smoothness, float skyLightmap, Mask mask) {
	if (isEyeInWater == 1) return;
	
	float firstStepSize = mix(1.0, 30.0, pow2(length((gbufferModelViewInverse * viewSpacePosition).xz) / 144.0));
	vec3  reflectedCoord;
	vec4  reflectedViewSpacePosition;
	vec3  reflection;
	float NoH;
	
	float roughness = 1.0 - smoothness;
	float alpha = pow2(roughness);
	float alpha2 = pow2(alpha);
	
	float F0 = undefF0;
	F0 = F0Calc(F0, mask.metallic);
	
	vec3 viewVector = -normalize(viewSpacePosition.xyz);
	
	float sunlight = ComputeShadows(viewSpacePosition, 1.0);
	skyLightmap = clamp01(pow(skyLightmap, 4));
	
	vec3 specular = specularBRDF(lightVector, normal, F0, viewVector, alpha, NoH) * sunlight * sunlightColor * 6.0;
	
	vec3 upVector = abs(normal.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
	vec3 tanX = normalize(cross(upVector, normal));
	vec3 tanY = cross(normal, tanX);
	
	for (uint i = 1; i <= PBR_RAYS; i++) {
		vec2 epsilon = Hammersley(i, PBR_RAYS);
		vec3 BRDFSkew = skew(epsilon, alpha2);
		
		vec3 microFacetNormal = BRDFSkew.x * tanX + BRDFSkew.y * tanY + BRDFSkew.z * normal;
		vec3 reflectDir = normalize(microFacetNormal); //Reproject normal in spherical coords
		vec3 rayDirection = reflect(-viewVector, reflectDir);
		
		float raySpecular = specularBRDF(rayDirection, microFacetNormal, F0, viewVector, sqrt(roughness), NoH);
		vec3 reflectedAmbient = CalculateSky(vec4(reflect(viewSpacePosition.xyz, microFacetNormal), 1.0), 1.0, true).rgb * skyLightmap * raySpecular * 0.5;
		reflectedAmbient += mask.metallic * (1.0 - skyLightmap) * 0.15;
		
		if (!ComputeRaytracedIntersection(viewSpacePosition.xyz, rayDirection, firstStepSize, 1.25, 25, 1, reflectedCoord, reflectedViewSpacePosition)) {
			reflection += specular + reflectedAmbient;
		} else {
			float lod = computeLod(NoH, PBR_RAYS, alpha);
			
			vec3 colorSample = GetColorLod(reflectedCoord.st, lod);
			colorSample = mix(colorSample, reflectedAmbient, CalculateFogFactor(reflectedViewSpacePosition, FOG_POWER));
			//Edge falloff was doing nothing and taking 1 fps so rip

			reflection += colorSample * raySpecular;
		}
	}
	
	reflection /= PBR_RAYS;
	
	blendRain(color, rainStrength, roughness);
	reflection = BlendMaterial(color, reflection, F0);

	color = max0(reflection);
}
#endif
