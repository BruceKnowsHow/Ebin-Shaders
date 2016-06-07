vec3 RayMarchClouds(in vec4 viewSpacePosition) {
  vec3 clouds;
  
  vec4 worldPosition = gbufferModelViewInverse * viewSpacePosition;
	worldPosition.xyz += cameraPosition.xyz;
  
  float rayDist = far;
  float rayStep = far / 10.0;
  
  float dankNoise;
  
  rayDist += dankNoise * rayStep;
  
  while(rayDist > 0.0) {
    clouds += vec3(0.0);
    
    rayDist -= rayStep;
  }
  
  return clouds;
}

vec3 CompositeClouds(in vec4 viewSpacePosition) {
  //return RayMarchClouds(viewSpacePosition);
  return vec3(0.0);
}
