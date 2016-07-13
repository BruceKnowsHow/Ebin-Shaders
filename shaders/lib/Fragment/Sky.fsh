float CalculateSunglow(in vec4 viewSpacePosition) {
	float sunglow = max0(dot(normalize(viewSpacePosition.xyz), lightVector) - 0.01);
	      sunglow = pow(sunglow, 8.0);
	
	return sunglow;
}

vec3 CalculateSkyGradient(in vec4 viewSpacePosition, in float fogFactor) {
	float radius = max(176.0, far * sqrt(2.0));
	
	vec4 worldPosition = gbufferModelViewInverse * vec4(normalize(viewSpacePosition.xyz), 0.0);
	
#ifdef CUSTOM_HORIZON_HEIGHT
	worldPosition.y  = radius * worldPosition.y / length(worldPosition.xz) + cameraPosition.y - HORIZON_HEIGHT; // Reproject the world vector to have a consistent horizon height
	worldPosition.xz = normalize(worldPosition.xz) * radius;
#endif
	
	float dotUP = dot(normalize(worldPosition.xyz), vec3(0.0, 1.0, 0.0));
	
	
	float gradientCoeff = pow(1.0 - abs(dotUP) * 0.5, 4.0);
	
	float sunglow = CalculateSunglow(viewSpacePosition);
	
	
	vec3 primaryHorizonColor  = SetSaturationLevel(skylightColor, mix(1.0, 0.5, gradientCoeff * timeDay));
	     primaryHorizonColor  = SetSaturationLevel(primaryHorizonColor, mix(1.0, 1.1, timeDay));
	     primaryHorizonColor *= (1.0 + gradientCoeff * 0.5);
	     primaryHorizonColor  = mix(primaryHorizonColor, sunlightColor, gradientCoeff * sunglow * timeDay);
	
	vec3 sunglowColor = mix(skylightColor, sunlightColor * 0.5, gradientCoeff * sunglow) * sunglow;
	
	
	vec3 color  = primaryHorizonColor * gradientCoeff * 8.0; // Sky desaturates as it approaches the horizon
	     color *= 1.0 + sunglowColor * 2.0;
	     color += sunglowColor * 5.0;
	
	return color * 0.9;
}

#define iSteps 8
#define jSteps 2

float rsi(vec3 r0, vec3 rd, float sr) {
	// Simplified ray-sphere intersection that assumes
	// the ray starts inside the sphere and that the
	// sphere is centered at the origin. Always intersects.
	float a = dot(rd, rd);
	float b = 2.0 * dot(rd, r0);
	float c = dot(r0, r0) - (sr * sr);
	return (-b + sqrt((b*b) - 4.0*a*c))/(2.0*a);
}

vec3 atmosphere(vec3 r, vec3 r0, vec3 pSun, float iSun, float rPlanet, float rAtmos, vec3 kRlh, float kMie, float shRlh, float shMie, float g) {
	// Normalize the sun and view directions.
	pSun = normalize(pSun);
	r = normalize(r);
	
	// Calculate the step size of the primary ray.
	float iStepSize = rsi(r0, r, rAtmos) / float(iSteps);
	
	// Initialize the primary ray time.
	float iTime = 0.0;
	
	// Initialize accumulators for Rayleigh and Mie scattering.
	vec3 totalRlh = vec3(0,0,0);
	vec3 totalMie = vec3(0,0,0);
	
	// Initialize optical depth accumulators for the primary ray.
	float iOdRlh = 0.0;
	float iOdMie = 0.0;
	
	// Calculate the Rayleigh and Mie phases.
	float mu = dot(r, pSun);
	float mumu = mu * mu;
	float gg = g * g;
	float pRlh = 3.0 / (16.0 * PI) * (1.0 + mumu);
	float pMie = 3.0 / (8.0 * PI) * ((1.0 - gg) * (mumu + 1.0)) / (pow(1.0 + gg - 2.0 * mu * g, 1.5) * (2.0 + gg));
	
	// Sample the primary ray.
	for (int i = 0; i < iSteps; i++) {
		
		// Calculate the primary ray sample position.
		vec3 iPos = r0 + r * (iTime + iStepSize * 0.5);
		
		// Calculate the height of the sample.
		float iHeight = length(iPos) - rPlanet;
		
		// Calculate the optical depth of the Rayleigh and Mie scattering for this step.
		float odStepRlh = exp(-iHeight / shRlh) * iStepSize;
		float odStepMie = exp(-iHeight / shMie) * iStepSize;
		
		// Accumulate optical depth.
		iOdRlh += odStepRlh;
		iOdMie += odStepMie;
		
		// Calculate the step size of the secondary ray.
		float jStepSize = rsi(iPos, pSun, rAtmos) / float(jSteps);
		
		// Initialize the secondary ray time.
		float jTime = 0.0;
		
		// Initialize optical depth accumulators for the secondary ray.
		float jOdRlh = 0.0;
		float jOdMie = 0.0;
		
		// Sample the secondary ray.
		for (int j = 0; j < jSteps; j++) {
			
			// Calculate the secondary ray sample position.
			vec3 jPos = iPos + pSun * (jTime + jStepSize * 0.5);
			
			// Calculate the height of the sample.
			float jHeight = length(jPos) - rPlanet;
			
			// Accumulate the optical depth.
			jOdRlh += exp(-jHeight / shRlh) * jStepSize;
			jOdMie += exp(-jHeight / shMie) * jStepSize;
			
			// Increment the secondary ray time.
			jTime += jStepSize;
		}
		
		// Calculate attenuation.
		vec3 attn = exp(-(kMie * (iOdMie + jOdMie) + kRlh * (iOdRlh + jOdRlh)));
		
		show(attn);
		
		// Accumulate scattering.
		totalRlh += odStepRlh * attn;
		totalMie += odStepMie * attn;
		
		// Increment the primary ray time.
		iTime += iStepSize;
    }
	
	// Calculate and return the final color.
	
	vec3 color = iSun * (pRlh * kRlh * totalRlh + pMie * kMie * totalMie);
	
//	if (any(isnan(color))) color = vec3(0.0);
	
	return color;
}

// math const
const float DEG_TO_RAD = PI / 180.0;
const float MAX = 100000.0;

// scatter const
const float K_R = 0.166;
const float K_M = 0.005;
const float E = 50.0; 						// light intensity
const vec3  C_R = vec3( 2.0, 7.5, 20.0 ) * 0.1; 	// 1 / wavelength ^ 4
const float G_M = 0.95;					// Mie g

const float R = 6471e3;
const float R_INNER = 6371e3;
const float SCALE_H = 4.0 / ( R - R_INNER );
const float SCALE_L = 1.0 / ( R - R_INNER );

const int NUM_OUT_SCATTER = 10;
const float FNUM_OUT_SCATTER = 10.0;

const int NUM_IN_SCATTER = 10;
const float FNUM_IN_SCATTER = 10.0;

// angle : pitch, yaw
mat3 rot3xy( vec2 angle ) {
	vec2 c = cos( angle );
	vec2 s = sin( angle );
	
	return mat3(
		c.y      ,  0.0, -s.y,
		s.y * s.x,  c.x,  c.y * s.x,
		s.y * c.x, -s.x,  c.y * c.x
	);
}

// ray direction
vec3 ray_dir( float fov, vec2 size, vec2 pos ) {
	vec2 xy = pos - size * 0.5;

	float cot_half_fov = tan( ( 90.0 - fov * 0.5 ) * DEG_TO_RAD );	
	float z = size.y * 0.5 * cot_half_fov;
	
	return normalize( vec3( xy, -z ) );
}

// ray intersects sphere
// e = -b +/- sqrt( b^2 - c )
vec2 ray_vs_sphere( vec3 p, vec3 dir, float r ) {
	float b = dot( p, dir );
	float c = dot( p, p ) - r * r;
	
	float d = b * b - c;
	if ( d < 0.0 ) {
		return vec2( MAX, -MAX );
	}
	d = sqrt( d );
	
	return vec2( -b - d, -b + d );
}

// Mie
// g : ( -0.75, -0.999 )
//      3 * ( 1 - g^2 )               1 + c^2
// F = ----------------- * -------------------------------
//      2 * ( 2 + g^2 )     ( 1 + g^2 - 2 * g * c )^(3/2)
float phase_mie( float g, float c, float cc ) {
	float gg = g * g;
	
	float a = ( 1.0 - gg ) * ( 1.0 + cc );

	float b = 1.0 + gg - 2.0 * g * c;
	b *= sqrt( b );
	b *= 2.0 + gg;	
	
	return 1.5 * a / b;
}

// Reyleigh
// g : 0
// F = 3/4 * ( 1 + c^2 )
float phase_reyleigh( float cc ) {
	return 0.75 * ( 1.0 + cc );
}

float density( vec3 p ){
	return exp( -( length( p ) - R_INNER ) * SCALE_H );
}

float optic( vec3 p, vec3 q ) {
	vec3 step = ( q - p ) / FNUM_OUT_SCATTER;
	vec3 v = p + step * 0.5;
	
	float sum = 0.0;
	for ( int i = 0; i < NUM_OUT_SCATTER; i++ ) {
		sum += density( v );
		v += step;
	}
	sum *= length( step ) * SCALE_L;
	
	return sum;
}

vec3 in_scatter( vec3 o, vec3 dir, vec2 e, vec3 l ) {
	float len = ( e.y - e.x ) / FNUM_IN_SCATTER;
	vec3 step = dir * len;
	vec3 p = o + dir * e.x;
	vec3 v = p + dir * ( len * 0.5 );

	vec3 sum = vec3( 0.0 );
	for ( int i = 0; i < NUM_IN_SCATTER; i++ ) {
		vec2 f = ray_vs_sphere( v, l, R );
		vec3 u = v + l * f.y;
		
		float n = ( optic( p, v ) + optic( v, u ) ) * ( PI * 4.0 );
		
		sum += density( v ) * exp( -n * ( K_R * C_R + K_M ) );

		v += step;
	}
	sum *= len * SCALE_L;
	
	float c  = dot( dir, -l );
	float cc = c * c;
	
	return sum * ( K_R * C_R * phase_reyleigh( cc ) + K_M * phase_mie( G_M, c, cc ) ) * E;
}

vec3 CalculateAtmosphericSky(in vec4 viewSpacePosition, in float fogFactor) {
	vec3 worldSpacePosition = (gbufferModelViewInverse * viewSpacePosition).xyz;
	vec3 worldLightVector   = (gbufferModelViewInverse * vec4(lightVector, 0.0)).xyz;
	vec3 r0                 = vec3(0.0, 6372e3 + (cameraPosition.y - 62.0), 0.0);
	
	
	// default ray dir
	vec3 dir = normalize(-worldSpacePosition);
	
	// default ray origin
	vec3 eye = r0;

	// sun light dir
	vec3 l = normalize(worldLightVector);
			  
	vec2 e = ray_vs_sphere( eye, dir, R );
	
	vec2 f = ray_vs_sphere( eye, dir, R_INNER );
	e.y = min( e.y, f.x );

	vec3 I = in_scatter( eye, dir, e, l );
	
	return I;
	
	/*
	return atmosphere(
		normalize(worldSpacePosition),  // normalized ray direction
		r0,               // ray origin
		worldLightVector,               // position of the sun
		40.0,                           // intensity of the sun
		6371e3,                         // radius of the planet in meters
		6471e3,                         // radius of the atmosphere in meters
		vec3(2.5e-6, 10.0e-6, 22.4e-6), // Rayleigh scattering coefficient
		21e-6,                          // Mie scattering coefficient
		8e3,                            // Rayleigh scale height
		1.2e3,                          // Mie scale height
		0.9                             // Mie preferred scattering direction
	); */
}

vec3 CalculateSunspot(in vec4 viewSpacePosition) {
	float sunspot  = max0(dot(normalize(viewSpacePosition.xyz), lightVector) - 0.01);
	      sunspot  = pow(sunspot, 350.0);
	      sunspot  = pow(sunspot + 1.0, 400.0) - 1.0;
	      sunspot  = min(sunspot, 20.0);
	      sunspot += 100.0 * float(sunspot == 20.0);
	
	return sunspot * sunlightColor * sunlightColor * vec3(1.0, 0.8, 0.6);
}

vec3 CalculateAtmosphereScattering(in vec4 viewSpacePosition) {
	float factor = pow(length(viewSpacePosition.xyz), 1.4) * 0.0001 * ATMOSPHERIC_SCATTERING_AMOUNT;
	
	return pow(skylightColor, vec3(2.5)) * factor;
}

#include "/lib/Fragment/Clouds.fsh"

vec3 CalculateSky(in vec4 viewSpacePosition, in float alpha, cbool reflection) {
	float visibility = CalculateFogFactor(viewSpacePosition, FOG_POWER);
	
	if (visibility < 0.001 && !reflection) return vec3(0.0);
	
	
	vec3 gradient = CalculateSkyGradient(viewSpacePosition, visibility);
	vec3 sunspot  = reflection ? vec3(0.0) : CalculateSunspot(viewSpacePosition) * pow(visibility, 25) * alpha;
	
	return (gradient + sunspot) * SKY_BRIGHTNESS;
}
