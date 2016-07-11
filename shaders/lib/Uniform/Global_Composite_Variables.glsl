varying mat4 shadowView;
#if defined fsh
	#define shadowModelView shadowView
#endif

varying vec3 lightVector;

varying float timeDay;
varying float timeNight;
varying float timeHorizon;

varying vec3 colorHorizon;

varying vec3 sunlightColor;
varying vec3 skylightColor;
