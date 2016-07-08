float AlchemyAO(in vec4 viewSpacePosition, in vec3 normal) {
  cfloat range = 2.0;
  cfloat falloffCap = 0.08 * range;
  cint numSamples = 20;
  
  float sampleArea = range / viewSpacePosition.z;
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
    float diffLength =  lengthSquared(differential);
    
    AO += (max(0.0, dot(normal, differential) + 0.0025 * viewSpacePosition.z) * step(sqrt(diffLength), range) * EdgeError) / (diffLength + 0.0001);
    angle += angleStep;
  }
  
  AO *= (2.0 * falloffCap) / numSamples;
  AO = max(0.0, 1.0 - AO);
  
  return AO;
}

// HBAO paper http://rdimitrov.twistedsanity.net/HBAO_SIGGRAPH08.pdf
// HBAO SIGGRAPH presentation http://developer.download.nvidia.com/presentations/2008/SIGGRAPH/HBAO_SIG08b.pdf
float CalculateHBAO(in vec4 viewSpacePosition, in vec3 normal) {
	cfloat sampleRadius = 0.5;
	cint sampleDirections = 4;
	cfloat sampleStep = 0.004;
	cint sampleStepCount = 8;
	cfloat tanBias = 0.2;
	
	cfloat sampleDirInc = 2.0 * 3.141 / sampleDirections;
	float ao;
	
	vec2 randomAngle = GetDitherred2DNoise(texcoord, 64.0).xy * 3.141 * 2.0;
	
	mat2 rotationMatrix = mat2(
		cos(randomAngle.x), -sin(randomAngle.x),
	  sin(randomAngle.y),  cos(randomAngle.y)); //Random Rotation Matrix
	
	for(uint i = 0; i < sampleDirections; i++) {
		float sampleAngle = i * sampleDirInc;
		vec2 sampleDir = vec2(cos(sampleAngle), sin(sampleAngle)) * rotationMatrix;
		
		float tangentAngle = acos(dot(vec3(sampleDir, 0.0), normal)) - (0.5 * 3.141) + tanBias;
		float horizonAngle = tangentAngle;
		vec3 prevDiff;
		
		for(uint j = 0; j < sampleStepCount; j++) {
			vec2 sampleOffset = float(j + 1) * sampleStep * sampleDir;
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
		ao += 1.0 - occlusion;
	}
	ao /= sampleDirections;
	
	return ao;
}

//#define HBAO

#ifdef HBAO
  #define CalculateSSAO(x, y) CalculateHBAO(x, y)
#else
  #define CalculateSSAO(x, y) AlchemyAO(x, y)
#endif
