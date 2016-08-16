#ifndef PBR
void ComputeReflectedLight(inout vec3 color, vec4 viewSpacePosition, vec3 normal, float smoothness, float skyLightmap, Mask mask) {
	if (isEyeInWater == 1) return;
	
	vec3  rayDirection  = normalize(reflect(viewSpacePosition.xyz, normal));
	float firstStepSize = mix(1.0, 30.0, pow2(length((gbufferModelViewInverse * viewSpacePosition).xz) / 144.0));
	vec3  reflectedCoord;
	vec4  reflectedViewSpacePosition;
	vec3  reflection;
	
	float roughness = 1.0 - smoothness;
	
	vec3 viewVector = -normalize(viewSpacePosition.xyz);
	vec3 halfVector = normalize(lightVector - viewVector);
	
	float vdotn   = clamp01(dot(viewVector, normal));
	float vdoth   = clamp01(dot(viewVector, halfVector));
	
	cfloat F0 = 0.15; //To be replaced with metalloic
	
	float  reflectFresnel = Fresnel(F0, vdotn);
	float  lightFresnel = Fresnel(F0, vdoth);
	
	vec3 alpha = vec3(lightFresnel * smoothness);
	
	if (length(alpha) < 0.001) return;
	
	
	float sunlight = ComputeShadows(viewSpacePosition, 1.0);
	
	vec3 reflectedSky  = CalculateSky(vec4(reflect(viewSpacePosition.xyz, normal), 1.0), 1.0, true).rgb;
	     reflectedSky *= 1.0;
	
	float reflectedSunspot = CalculateSpecularHighlight(lightVector, normal, lightFresnel, -normalize(viewSpacePosition.xyz), roughness) * sunlight;
	
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
float noise(vec2 coord) {
    return fract(sin(dot(coord, vec2(12.9898, 4.1414))) * 43758.5453);
}

void ComputeReflectedLight(inout vec3 color, vec4 viewSpacePosition, vec3 normal, float smoothness, float skyLightmap, Mask mask) {
	if (isEyeInWater == 1) return;
	
	float firstStepSize = mix(1.0, 30.0, pow2(length((gbufferModelViewInverse * viewSpacePosition).xz) / 144.0));
	vec3  reflectedCoord;
	vec4  reflectedViewSpacePosition;
	vec3  reflection;
	
	float roughness = 1.0 - smoothness;
	
	float F0 = undefF0;
	F0 = F0Calc(F0, mask.metallic);
	
	vec3 viewVector = -normalize(viewSpacePosition.xyz);
	vec3 halfVector = normalize(lightVector - viewVector);
	
	float vdotn   = clamp01(dot(viewVector, normal));
	float vdoth   = clamp01(dot(viewVector, halfVector));
	
	float  reflectFresnel = Fresnel(F0, vdotn);
	float  lightFresnel = Fresnel(F0, vdoth);
	
	float sunlight = ComputeShadows(viewSpacePosition, 1.0);
	
	vec3 reflectedSky  = CalculateSky(vec4(reflect(viewSpacePosition.xyz, normal), 1.0), 1.0, true).rgb * clamp01(pow(skyLightmap, 10));
	float specular = CalculateSpecularHighlight(lightVector, normal, lightFresnel, -normalize(viewSpacePosition.xyz), roughness) * sunlight;
	
	if(mask.water < 0.5) reflectedSky = clamp01(reflectedSky * F0);
	vec3 offscreen = (reflectedSky + specular * sunlightColor * 0.25) / 2.0;
	
	for (uint i = 1; i <= PBR_RAYS; i++) {
		vec2 epsilon = vec2(noise(texcoord * (i + 1)), noise(texcoord * (i + 1) * 3));
		vec3 BRDFSkew = skew(epsilon, pow2(roughness));
		
		vec3 reflectDir  = normalize(BRDFSkew * roughness / 8.0 + normal);
		     reflectDir *= sign(dot(normal, reflectDir));
		
		vec3 rayDirection = reflect(normalize(viewSpacePosition.xyz), reflectDir);
		
		if (!ComputeRaytracedIntersection(viewSpacePosition.xyz, rayDirection, firstStepSize, 1.55, 30, 1, reflectedCoord, reflectedViewSpacePosition)) { //this is much faster I tested
			reflection += offscreen;
		} else {
			// Maybe give previous reflection Intersection to make sure we dont compute rays in the same pixel twice.
			
			vec3 colorSample = GetColorLod(reflectedCoord.st, 2);
			
			colorSample = mix(colorSample, reflectedSky, CalculateFogFactor(reflectedViewSpacePosition, FOG_POWER));
			
			#ifdef REFLECTION_EDGE_FALLOFF
				float angleCoeff = clamp(pow(dot(vec3(0.0, 0.0, 1.0), normal) + 0.15, 0.25) * 2.0, 0.0, 1.0) * 0.2 + 0.8;
				float dist       = length8(abs(reflectedCoord.xy - vec2(0.5)));
				float edge       = clamp(1.0 - pow2(dist * 2.0 * angleCoeff), 0.0, 1.0);
				colorSample      = mix(colorSample, reflectedSky, pow(1.0 - edge, 10.0));
			#endif
			
			reflection += colorSample * reflectFresnel * pow(smoothness, 4.0);
		}
	}
	
	reflection /= PBR_RAYS;
	if(mask.metallic > 0.45) reflection += (1.0 - clamp01(pow(skyLightmap, 10))) * 0.25;
	
	reflection = BlendMaterial(color, reflection, F0, smoothness);
	
	reflection = max(reflection, 0.0);
	
	color = reflection;
}
#endif
