// #include "/lib/Uniform/ShadowViewMatrix.vsh"

varying mat4 shadowView;
varying mat4 shadowViewInverse;

float timeCycle;
float timeAngle;
float pathRotationAngle;
float twistAngle;


#include "/lib/EbinScript/Load.vsh"
#include "/UserProgram/CustomTimeCycle.vsh"
#include "/lib/EbinScript/Unload.vsh"


float CalculateShadowView() {
	
	timeAngle = sunAngle * 360.0;
	pathRotationAngle = sunPathRotation;
	twistAngle = 0.0;
	
	
	UserRotation();
	
	
	timeCycle = timeAngle;
	
	float isNight = abs(sign(float(mod(timeAngle, 360.0) > 180.0) - float(mod(abs(pathRotationAngle) + 90.0, 360.0) > 180.0))); // When they're not both above or below the horizon
	
	timeAngle = -mod(timeAngle, 180.0) * RAD;
	pathRotationAngle = (mod(pathRotationAngle + 90.0, 180.0) - 90.0) * RAD;
	twistAngle *= RAD;
	
	
	float A = cos(pathRotationAngle);
	float B = sin(pathRotationAngle);
	float C = cos(timeAngle);
	float D = sin(timeAngle);
	float E = cos(twistAngle);
	float F = sin(twistAngle);
	
	shadowView = mat4(
	-D*E + B*C*F,  -A*F,  C*E + B*D*F,  shadowModelView[0].w,
	        -A*C,    -B,         -A*D,  shadowModelView[1].w,
	 B*C*E + D*F,  -A*E,  B*D*E - C*F,  shadowModelView[2].w,
	 shadowModelView[3]);
	
	shadowViewInverse = mat4(
	-E*D + F*B*C,  -C*A,  F*D + E*B*C,  0.0,
	        -F*A,    -B,         -E*A,  0.0,
	 F*B*D + E*C,  -A*D,  E*B*D - F*C,  0.0,
	         0.0,   0.0,          0.0,  1.0);
	
//	shadowViewInverse = mat4(
//	-E*D + F*B*C,  -C*A,  F*D + E*B*C,  shadowModelViewInverse[0].w,
//	        -F*A,    -B,         -E*A,  shadowModelViewInverse[1].w,
//	 F*B*D + E*C,  -A*D,  E*B*D - F*C,  shadowModelViewInverse[2].w,
//	 shadowModelViewInverse[3]);
	
	return isNight;
}
