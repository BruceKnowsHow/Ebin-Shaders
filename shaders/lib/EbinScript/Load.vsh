#define time frameTimeCounter
#define dayCycle sunAngle

#ifdef shadow_vsh
	#define position cameraPosition
#else
	#define position previousCameraPosition
#endif
