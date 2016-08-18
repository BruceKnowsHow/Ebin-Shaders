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
	
	float  lightFresnel = Fresnel(F0, vdoth);
	
	vec3 alpha = vec3(lightFresnel * smoothness);
	
	if (length(alpha) < 0.001) return;
	
	
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
	
	color = mix(color, reflection, alpha * 0.25);
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
	
	float F0 = undefF0;
	F0 = F0Calc(F0, mask.metallic);
	
	vec3 viewVector = -normalize(viewSpacePosition.xyz);
	
	float sunlight = ComputeShadows(viewSpacePosition, 1.0);
	const uint NUM_SAMPLES = PBR_RAYS;
	
	float specular = specularBRDF(lightVector, normal, F0, viewVector, pow2(roughness), NoH) * sunlight;
		
	vec3 offscreen = (specular * sunlightColor * 6.0);
	
	vec3 upVector = abs(normal.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
	vec3 tanX = normalize(cross(upVector, normal));
	vec3 tanY = cross(normal, tanX);
	
	for (uint i = 1; i < NUM_SAMPLES; i++) {
		vec2 epsilon = Hammersley(i, NUM_SAMPLES);
		vec3 BRDFSkew = skew(epsilon, pow(roughness, 4.0));
		
		vec3 microFacetNormal = BRDFSkew.x * tanX + BRDFSkew.y * tanY + BRDFSkew.z * normal;
		vec3 reflectDir = normalize(microFacetNormal); //Reproject normal in spherical coords

		vec3 rayDirection = reflect(-viewVector, reflectDir);
		float raySpecular = specularBRDF(rayDirection, microFacetNormal, F0, viewVector, sqrt(roughness), NoH);
		
		vec3 reflectedSky  = CalculateSky(vec4(reflect(viewSpacePosition.xyz, microFacetNormal), 1.0), 1.0, true).rgb * clamp01(pow(skyLightmap, 4)) * 0.5;

		if (!ComputeRaytracedIntersection(viewSpacePosition.xyz, rayDirection, firstStepSize, 1.25, 35, 1, reflectedCoord, reflectedViewSpacePosition)) {
			reflection += offscreen + reflectedSky * raySpecular;
		} else {
			// Maybe give previous reflection Intersection to make sure we dont compute rays in the same pixel twice.
			
			float lod = computeLod(NoH, NUM_SAMPLES, pow2(roughness));
			vec3 colorSample = GetColorLod(reflectedCoord.st, lod * 0.5) * 1.2;

			colorSample = mix(colorSample, reflectedSky, CalculateFogFactor(reflectedViewSpacePosition, FOG_POWER));
			
			#ifdef REFLECTION_EDGE_FALLOFF
				float angleCoeff = clamp(pow(dot(vec3(0.0, 0.0, 1.0), normal) + 0.15, 0.25) * 2.0, 0.0, 1.0) * 0.2 + 0.8;
				float dist       = length8(abs(reflectedCoord.xy - vec2(0.5)));
				float edge       = clamp(1.0 - pow2(dist * 2.0 * angleCoeff), 0.0, 1.0);
				colorSample      = mix(colorSample, reflectedSky, pow(1.0 - edge, 10.0));
			#endif

			reflection += colorSample * raySpecular;
		}
	}
	
	reflection /= PBR_RAYS;

	if(mask.metallic > 0.45) reflection += (1.0 - clamp01(pow(skyLightmap, 10))) * 0.25;
	
	blendRain(color, rainStrength, roughness);
	reflection = BlendMaterial(color, reflection, F0);

	color = max0(reflection);

}
#endif
