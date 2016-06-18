// #include "/lib/Fragment/Clouds.fsh"

vec3 GetCloud(in vec3 worldSpacePosition) {
	return vec3(float(abs(worldSpacePosition.x) < 100.0
	               && abs(worldSpacePosition.z) < 100.0
	               && abs(worldSpacePosition.y - 200.0) < 10.0));
}

vec3 RayMarchClouds(in vec4 viewSpacePosition) {
	vec3 clouds = vec3(0.0);
	
	
	float rayDist = far;
	vec3  rayStep = normalize(viewSpacePosition.xyz);
	float rayIncrement = 1.0;
	vec4  ray     = vec4(rayStep, 1.0);
	
	ray = gbufferModelViewInverse * ray;
	
	ray.y += cameraPosition.y;
	ray.xyz *= 190.0 / abs(ray.y);
	ray.y -= 190.0;
	
	ray = gbufferModelView * ray;
	
	uint count = 0;
	
	while(count < 400) {
		vec3 worldPosition = (gbufferModelViewInverse * ray).xyz + cameraPosition.xyz;
		
		clouds += GetCloud(worldPosition);
		
		ray.xyz += rayStep * rayIncrement;
		
		rayIncrement *= 1.01;
		
		count++;
	}
	
	return clouds * clouds * 0.01;
}

vec3 CompositeClouds(in vec4 viewSpacePosition) {
	//return RayMarchClouds(viewSpacePosition);
	return vec3(0.0);
}
