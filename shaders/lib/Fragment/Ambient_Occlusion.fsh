#ifndef AO_ENABLED

#define CalculateSSAO(a, b) 1.0

#elif AO_MODE == 1 // AlchemyAO
float CalculateSSAO(in vec4 viewSpacePosition, in vec3 normal) {
	cfloat sampleRadius   = 0.5;
	cfloat shadowScalar   = 0.1;
	cfloat depthThreshold = 0.0025;
	cfloat shadowContrast = 0.5;
	cint   numSamples     = 6;
	
	float sampleArea = sampleRadius / viewSpacePosition.z;
	float sampleStep = sampleArea   / numSamples;
	
	float angle     = GetDitherred2DNoise(texcoord * COMPOSITE0_SCALE, 64.0).x * PI * 2.0;
	float angleStep = PI * 2.0 / numSamples;
	
	float AO = 0.0;
	
	for(int i = 0; i < numSamples; i++) {
		vec2 pixelOffset = vec2(sampleStep * cos(angle), sampleStep * sin(angle));
		vec2 offsetCoord = texcoord + pixelOffset;
		
		float EdgeError = step(0.0, offsetCoord.x) * step(0.0, 1.0 - offsetCoord.x) *
		                  step(0.0, offsetCoord.y) * step(0.0, 1.0 - offsetCoord.y);
		
		vec3 offsetPosition = CalculateViewSpacePosition(offsetCoord, GetDepth(offsetCoord)).xyz;
		vec3 differential   = offsetPosition - viewSpacePosition.xyz;
		
		float diffLength = lengthSquared(differential);
		
		AO    += (max(0.0, dot(normal, differential) + depthThreshold * viewSpacePosition.z) * step(sqrt(diffLength), sampleRadius) * EdgeError) / max(pow2(shadowScalar), (diffLength + 0.0001));
		angle += angleStep;
	}
  
	AO *= (2.0 * shadowScalar) / numSamples;
	AO  = max(0.0, 1.0 - pow(AO, shadowContrast));
	
	return AO;
}

#else // HBAO

// HBAO paper http://rdimitrov.twistedsanity.net/HBAO_SIGGRAPH08.pdf
// HBAO SIGGRAPH presentation http://developer.download.nvidia.com/presentations/2008/SIGGRAPH/HBAO_SIG08b.pdf
float CalculateSSAO(in vec4 viewSpacePosition, in vec3 normal) {
	cfloat sampleRadius     = 0.5;
	cint   sampleDirections = 6;
	cfloat sampleStep       = 0.016;
	cint   sampleStepCount  = 2;
	cfloat tanBias          = 0.2;
	
	float AO;
	
	vec2 noise = GetDitherred2DNoise(texcoord * COMPOSITE0_SCALE, 64.0).xy;
	
	float  angle = noise.x * 2.0 * PI;
	cfloat sampleDirInc = 2.0 * PI / sampleDirections;
	
	for(uint i = 0; i < sampleDirections; i++) {
		vec2 sampleDir = vec2(cos(angle), sin(angle));
		
		angle += sampleDirInc;
		
		float tangentAngle = acos(dot(vec3(sampleDir, 0.0), normal)) - (PI * 0.5) + tanBias;
		float horizonAngle = tangentAngle;
		
		vec3 prevDiff;
		
		for(uint j = 0; j < sampleStepCount; j++) {
			vec2 sampleOffset = (j + noise.y) * sampleStep * sampleDir;
			vec2 offsetCoord  = texcoord + sampleOffset;
			
			float offsetDepth = GetDepth(offsetCoord);
			
			vec3 offsetViewSpace = CalculateViewSpacePosition(offsetCoord, offsetDepth).xyz;
			vec3 differential    = offsetViewSpace - viewSpacePosition.xyz;
			
			if(length(differential) < sampleRadius) {
				prevDiff = differential;
				
				float elevationAngle = atan(differential.z / length(differential.xy));
				
				horizonAngle = max(horizonAngle, elevationAngle);
			}
		}
		
		float attenuation = 1.0 / (1.0 + length(prevDiff));
		float occlusion = clamp01(attenuation * (sin(horizonAngle) - sin(tangentAngle)));
		
		AO += occlusion;
	}
	
	AO *= 3.0 / (sampleDirections * sampleStepCount);
	AO  = clamp01(1.0 - sqrt(AO));
	
	return AO;
}
#endif
