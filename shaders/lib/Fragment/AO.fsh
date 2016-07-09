float AlchemyAO(in vec4 viewSpacePosition, in vec3 normal) {
  cfloat sampleRadius = 0.5;
  cfloat shadowScalar = 0.1;
  cfloat depthThreshold = 0.0025;
  cfloat shadowContrast = 0.5;
  cint numSamples = 6;
  
  float sampleArea = sampleRadius / viewSpacePosition.z;
  float sampleStep = sampleArea / numSamples;
  
  float angle = GetDitherred2DNoise(texcoord * COMPOSITE0_SCALE, 64.0).x * 2.0 * 3.14159;
  float angleStep = 2.0 * 3.14159 / numSamples;
  
  float AO = 0.0;
  
  for(int i = 0; i < numSamples; i++) {
    vec2 pixelOffset = vec2(sampleStep * cos(angle), sampleStep * sin(angle));
    vec2 offsetCoord = texcoord + pixelOffset;
    
    float EdgeError = step(0.0, offsetCoord.x) * step(0.0, 1.0 - offsetCoord.x) *
                      step(0.0, offsetCoord.y) * step(0.0, 1.0 - offsetCoord.y);
    
    vec3 offsetPosition = CalculateViewSpacePosition(offsetCoord, GetDepth(offsetCoord)).xyz;
    vec3 differential = offsetPosition - viewSpacePosition.xyz;
    float diffLength = lengthSquared(differential);
    
    AO += (max(0.0, dot(normal, differential) + depthThreshold * viewSpacePosition.z) * step(sqrt(diffLength), sampleRadius) * EdgeError) / max(pow2(shadowScalar), (diffLength + 0.0001));
    angle += angleStep;
  }
  
  AO *= (2.0 * shadowScalar) / numSamples;
  AO = max(0.0, 1.0 - pow(AO, shadowContrast));
  
  return AO;
}

// HBAO paper http://rdimitrov.twistedsanity.net/HBAO_SIGGRAPH08.pdf
// HBAO SIGGRAPH presentation http://developer.download.nvidia.com/presentations/2008/SIGGRAPH/HBAO_SIG08b.pdf
float CalculateHBAO(in vec4 viewSpacePosition, in vec3 normal) {
	cfloat sampleRadius = 0.5;
	cint sampleDirections = 6;
	cfloat sampleStep = 0.016;
	cint sampleStepCount = 2;
	cfloat tanBias = 0.2;
	
	float ao;
	
  vec2 noise = GetDitherred2DNoise(texcoord * COMPOSITE0_SCALE, 64.0).xy;
	float angle = noise.x * 2.0 * 3.14159;
  cfloat sampleDirInc = 2.0 * 3.14159 / sampleDirections;
	
	for(uint i = 0; i < sampleDirections; i++) {
		vec2 sampleDir = vec2(cos(angle), sin(angle));
    angle += sampleDirInc;
		
		float tangentAngle = acos(dot(vec3(sampleDir, 0.0), normal)) - (0.5 * 3.14159) + tanBias;
		float horizonAngle = tangentAngle;
		vec3 prevDiff;
		
		for(uint j = 0; j < sampleStepCount; j++) {
			vec2 sampleOffset = float(j + noise.y) * sampleStep * sampleDir;
			vec2 offsetCoord = texcoord + sampleOffset;
			
			float offsetDepth = GetDepth(offsetCoord);
			vec3 offsetViewSpace = CalculateViewSpacePosition(offsetCoord, offsetDepth).xyz;
			vec3 differential = offsetViewSpace - viewSpacePosition.xyz;
      
			if(length(differential) < sampleRadius) {
				prevDiff = differential;
				float elevationAngle = atan(differential.z / length(differential.xy));
				horizonAngle = max(horizonAngle, elevationAngle);
			}
		}
		float attenuation = 1.0 / (1.0 + length(prevDiff));
		float occlusion = clamp01(attenuation * (sin(horizonAngle) - sin(tangentAngle)));
		ao += occlusion;
	}
	ao *= 3.0 / (sampleDirections * sampleStepCount);
  ao = clamp01(1.0 - pow(ao, 0.5));
	
	return ao;
}

//#define HBAO

#ifdef HBAO
  #define CalculateSSAO(x, y) CalculateHBAO(x, y)
#else
  #define CalculateSSAO(x, y) AlchemyAO(x, y)
#endif
