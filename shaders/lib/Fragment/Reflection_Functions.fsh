#ifndef PBR
void ComputeReflectedLight(inout vec3 color, in vec4 viewSpacePosition, in vec3 normal, in float smoothness, in float skyLightmap, in Mask mask) {
	if (mask.water < 0.5) smoothness = pow(smoothness, 2.0) * 0.85;
	
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
	
	vec3  sColor  = mix(vec3(0.15), color * 0.2, vec3(mask.metallic));
	vec3  reflectFresnel = Fresnel(sColor, vdotn);
	vec3  lightFresnel = Fresnel(sColor, vdoth);
	
	vec3 alpha = reflectFresnel * smoothness;
	
	if (length(alpha) < 0.001) return;
	
	
	float sunlight = ComputeShadows(viewSpacePosition, 1.0);
	
	vec3 reflectedSky  = CalculateSky(vec4(reflect(viewSpacePosition.xyz, normal), 1.0), 1.0, true).rgb;
	     reflectedSky *= 1.0;
	
	vec3 reflectedSunspot = CalculateSpecularHighlight(lightVector, normal, lightFresnel, -normalize(viewSpacePosition.xyz), roughness) * sunlight;
	
	vec3 offscreen = reflectedSky + reflectedSunspot * sunlightColor * 100.0 * 0;
	
	if (!ComputeRaytracedIntersection(viewSpacePosition.xyz, rayDirection, firstStepSize, 1.3, 30, 3, reflectedCoord, reflectedViewSpacePosition))
		reflection = offscreen;
	else {
		reflection = GetColor(reflectedCoord.st);
		
		vec3 reflectionVector = normalize(reflectedViewSpacePosition.xyz - viewSpacePosition.xyz) * length(reflectedViewSpacePosition.xyz); // This is not based on any physical property, it just looked around when I was toying around
		
	//	CompositeFog(reflection, vec4(reflectionVector, 1.0), GetVolumetricFog(reflectedCoord.st));
		
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
float noise(in vec2 coord) {
    return fract(sin(dot(coord, vec2(12.9898, 4.1414))) * 43758.5453);
}

void ComputeReflectedLight(inout vec3 color, in vec4 viewSpacePosition, in vec3 normal, in float smoothness, in float skyLightmap, in Mask mask) {
	if (mask.water < 0.5) smoothness = pow(smoothness, 4.8);
	
	float firstStepSize = mix(1.0, 30.0, pow2(length((gbufferModelViewInverse * viewSpacePosition).xz) / 144.0));
	vec3  reflectedCoord;
	vec4  reflectedViewSpacePosition;
	vec3  reflection;
	
	float roughness = 1.0 - smoothness;
	
	#define IOR 0.15 // [0.05 0.1 0.15 0.25 0.5]
	
	vec3 viewVector = -normalize(viewSpacePosition.xyz);
	vec3 halfVector = normalize(lightVector - viewVector);
	
	float vdotn   = clamp01(dot(viewVector, normal));
	float vdoth   = clamp01(dot(viewVector, halfVector));
	
	vec3  sColor  = mix(vec3(IOR), clamp(color * 0.25, 0.02, 0.99), vec3(mask.metallic));
	vec3  reflectFresnel = Fresnel(sColor, vdotn);
	vec3  lightFresnel = Fresnel(sColor, vdoth);
	
	vec3 alpha = reflectFresnel * smoothness;
	if(mask.metallic > 0.1) alpha = sColor;
	
	//This breaks some things.
	//if (length(alpha) < 0.01) return;
	
	float sunlight = ComputeShadows(viewSpacePosition, 1.0);
	
	vec3 reflectedSky  = CalculateSky(vec4(reflect(viewSpacePosition.xyz, normal), 1.0), 1.0, true).rgb;
	vec3 reflectedSunspot = CalculateSpecularHighlight(lightVector, normal, lightFresnel, -normalize(viewSpacePosition.xyz), roughness) * sunlight;
	
	vec3 offscreen = (reflectedSky + reflectedSunspot * sunlightColor * 100.0);
	if(mask.metallic > 0.5) offscreen *= smoothness + 0.1;
	
	for (uint i = 1; i <= PBR_RAYS; i++) {
		vec2 epsilon = vec2(noise(texcoord * (i + 1)), noise(texcoord * (i + 1) * 3));
		vec3 BRDFSkew = skew(epsilon, pow2(roughness));
		
		vec3 reflectDir  = normalize(BRDFSkew * roughness / 8.0 + normal);
		     reflectDir *= sign(dot(normal, reflectDir));
		
		vec3 rayDirection = reflect(normalize(viewSpacePosition.xyz), reflectDir);
		
		if (!ComputeRaytracedIntersection(viewSpacePosition.xyz, rayDirection, firstStepSize, 1.3, 30, 3, reflectedCoord, reflectedViewSpacePosition)) { //this is much faster I tested
			reflection += offscreen + 0.5 * mask.metallic;
		} else {
			vec3 reflectionVector = normalize(reflectedViewSpacePosition.xyz - viewSpacePosition.xyz) * length(reflectedViewSpacePosition.xyz); // This is not based on any physical property, it just looked around when I was toying around
			// Maybe give previous reflection Intersection to make sure we dont compute rays in the same pixel twice.
			
			vec3 colorSample = GetColorLod(reflectedCoord.st, 2);
			
			//CompositeFog(colorSample, vec4(reflectionVector, 1.0), GetVolumetricFog(reflectedCoord.st));
			
			#ifdef REFLECTION_EDGE_FALLOFF
				float angleCoeff = clamp(pow(dot(vec3(0.0, 0.0, 1.0), normal) + 0.15, 0.25) * 2.0, 0.0, 1.0) * 0.2 + 0.8;
				float dist       = length8(abs(reflectedCoord.xy - vec2(0.5)));
				float edge       = clamp(1.0 - pow2(dist * 2.0 * angleCoeff), 0.0, 1.0);
				colorSample      = mix(colorSample, reflectedSky, pow(1.0 - edge, 10.0));
			#endif
			
			reflection += colorSample;
		}
	}
	
	reflection /= PBR_RAYS;
	
	reflection = max(reflection, 0.0);
	
	color = mix(color * (1.0 - mask.metallic), reflection, alpha);
}
#endif
