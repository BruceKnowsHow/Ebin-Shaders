//Okay so these clouds are quite complex and will continue to evolve to more and more types. This file is going to be hellish
//So to start we need a few functions like dithering spaces and a worldspace noise pattern so that is incoming.


//This is a 8x8 dither pattern, it is easily filterable from bilateral blurs so this is my choise.
// dirived from: http://devlog-martinsh.blogspot.nl/2011/03/glsl-8x8-bayer-matrix-dithering.html
float dither8(vec2 pos) {
	const int ditherPattern[64] = int[64](
  	0, 32, 8, 40, 2, 34, 10, 42, /* 8x8 Bayer ordered dithering */
  	48, 16, 56, 24, 50, 18, 58, 26, /* pattern. Each input pixel */
  	12, 44, 4, 36, 14, 46, 6, 38, /* is scaled to the 0..63 range */
  	60, 28, 52, 20, 62, 30, 54, 22, /* before looking in this table */
  	3, 35, 11, 43, 1, 33, 9, 41, /* to determine the action. */
  	51, 19, 59, 27, 49, 17, 57, 25,
  	15, 47, 7, 39, 13, 45, 5, 37,
  	63, 31, 55, 23, 61, 29, 53, 21);

	vec2 positon = vec2(floor(mod(texcoord.s * viewWidth, 8.0f)), floor(mod(texcoord.t * viewHeight, 8.0f)));
	int dither = ditherPattern[int(positon.x) + int(positon.y) * 8];

	return float(dither) / 64.0f;
}

//We need linear depth for clouds so that the marches stay performant.
float linearDepth(float depth) {
	return (far * (depth - near)) / (depth * (far - near));
}


vec3 CloudSpace(float minDist){
	vec4 rayworldposition = gbufferProjectionInverse * vec4(vec3(texcoord.st, linearDepth(minDist)) * 2.0 - 1.0, 1.0);
	rayworldposition /= rayworldposition.w;

	rayworldposition = gbufferModelViewInverse * rayworldposition;
	rayworldposition /= rayworldposition.w;

	rayworldposition.xyz += cameraPosition.xyz;

	return rayworldposition.rgb;
}


//Noise is one of the most important aspects of this. clouds could not be possible without them.
float Get3DNoise(in vec3 pos) {
	vec3 part  = floor(pos);
	vec3 whole = fract(pos);

	cvec2 zscale = vec2(17.0, 0.0);

	vec4 coord = part.xyxy + whole.xyxy + part.z * zscale.x + zscale.yyxx + 0.5;
	     coord /= noiseTextureResolution;

	float Noise1 = texture2D(noisetex, coord.xy).x;
	float Noise2 = texture2D(noisetex, coord.zw).x;

	return mix(Noise1, Noise2, whole.z);
}

/////////////////////////////////////////////////////////////////////////
//This point is where we have the patters for multiple volumetric clouds.
float cumulusFBM(vec3 pos, float time) {
	pos.x -= time * 0.04;

	float noise = Get3DNoise(pos);

	pos *= 4.0;
	pos.x += time * 0.02;

	noise += (1.0 - abs(Get3DNoise(pos) * 3.0 - 1.0)) * 0.20;

	pos    *= 3.0;
	pos.xz += time * 0.05;

	noise += (1.0 - abs(Get3DNoise(pos) * 3.0 - 1.5) - 0.2) * 0.065;

	pos.xz -= time * 0.115;

	noise += (1.0 - abs(Get3DNoise(pos) * 3.0 - 1.0)) * 0.05;

	pos *= 2.0;

	noise += (1.0 - abs(Get3DNoise(pos) * 2.0 - 1.0)) * 0.015;

	noise /= 1.4;

	return noise;
}

/////////////////////////////////////////////////////////////////////////
//This point is where we color and compile each cloud type.

float cumulusClouds(in vec3 rayPos, float steps, in float rayDepth) {
	float cloudHeight = 1000.0;
	float cloudShapeMult = 2.0;

	cloudShapeMult = cloudShapeMult * (1.0 + (rayPos.y * 0.5));

	float cloud = cloudHeight + cloudShapeMult;
	float cloudInv = cloudHeight - cloudShapeMult;

	if (rayPos.y < cloudInv || rayPos.y > cloud)
		return 0.0;

	float cloudHeightGradiant = clamp01((rayPos.y - cloudInv) / (cloudShapeMult * 0.5));

	vec3 position = rayPos / 300.0;

	float cumulus = cumulusFBM(position, TIME);
	float cloudMod = 1.0 - clamp01((rayPos.y - cloudHeight) / cloudShapeMult);
	float coverage = 0.93 - rainStrength * 0.93;

	cumulus *= pow(cloudMod * 1.7 * coverage * cloudHeightGradiant, 1.2);
	cumulus = pow(cumulus, 50.0);

	if(cumulus < 0.001)
		return 0.0;

	float cloudDepth = clamp01(distance(rayDepth, cloudHeight));

	return cumulus;
}

vec3 cloudLighting(in vec3 position) {
    // What to do:
    //
    // Find five points in a cone going from position toward the light vector
    // For each of those points, calculate the amount of cloud at that point
    // Additionally, generate one point directly in the direction of the light and farther away than the points in the cone.
    // How much farther? fuck if I know. Try twice or three times the distance
    // Get the amount of clouds at the far away point. This amount is now called Of
    // Sum all those cloud amounts together. That sum will now be called O
    // O is the amount of light occlusion at your cloud. You should multiply your ambient light by 1 - O
    // Of is how much the sun is occluded by far away clouds, and O is the amount that the sun is occluded in total.
    // The sun should be occluded by max(O, Of)
    // Now you have two numbers: ambient light strength and direct light strength. Multiply them by their respective colors and add
    // them together. Return this term.
		
		//Edit: Instead of just multiplying the two terms together firstly add beersPowderLaw to compute the amount of light that is going toward the eye.
		//Add a 2 lobed phase function to simulate silver lining and more correct light scattering.
		//use an energy conservitive method to compile these features (S - S * exp(-at * O)) / at 
		
		return vec3(1.0);
}

vec3 RayMarchClouds(in vec4 viewSpacePosition) {
	vec3 worldPosition = (gbufferModelViewInverse * viewSpacePosition).xyz;
	float worldDistance = length(worldPosition.xyz);
	float worldPositionSize = 1.953125;

	float rayStep = far / 2.0;
	float dither = dither8(texcoord) * rayStep;

	float rayDepth = far - 10.0 + dither;
	float rayWeight = rayDepth / rayStep;

	vec4 clouds;

	while(rayDepth > 0.0) {
		vec3 rayPosition = CloudSpace(rayDepth);

		clouds.a += cumulusClouds(rayPosition * worldPositionSize, rayStep, rayDepth);
    clouds.rgb += cloudLighting(rayPosition * worldPositionSize);

    // Optimization: When we've accumulated a full cloud, break.
    if(clouds.a > 1.0) break;

		float marchDepth = length((rayPosition - cameraPosition) / worldPositionSize);

		//if (worldDistance < marchDepth * worldPositionSize)
			//clouds = vec4(0.0);

		rayDepth -= rayStep;
	}

	clouds /= rayWeight;

	clouds.rgb = mix(vec3(0.0), clouds.rgb * 10, min(1.0, clouds.a));


	return clouds.rgb;
}

vec3 CompositeClouds(in vec4 viewSpacePosition) {
	return RayMarchClouds(viewSpacePosition);
	//return vec3(0.0);
}
