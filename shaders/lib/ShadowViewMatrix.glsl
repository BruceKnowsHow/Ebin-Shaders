
// Start of #include "/lib/ShadowViewMatrix.glsl"

// Prerequisites:
// 
// uniform mat4  shadowModelView;
// uniform float sunAngle;
// 
// varying mat4 shadowView;
// 
// #include "/lib/Settings.glsl"


void CalculateShadowView() {
	float timeAngle = -mod(sunAngle, 0.5) * 360.0 * RAD;
	float pathRotationAngle = sunPathRotation * RAD;
	float twistAngle = 0.0;
	
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
	
//	shadowViewInverse = mat4(
//	-E*D + F*B*C,  -C*A,  F*D + E*B*C,  shadowModelViewInverse[0].w,
//	        -F*A,    -B,         -E*A,  shadowModelViewInverse[1].w,
//	 F*B*D + E*C,  -A*D,  E*B*D - F*C,  shadowModelViewInverse[2].w,
//	 shadowModelViewInverse[3]);
}


// End of #include "/lib/ShadowViewMatrix.glsl"
