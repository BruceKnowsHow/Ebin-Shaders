
// Start of #include "/lib/EbinScript/Load.vsh"


#define time frameTimeCounter
#define dayCycle sunAngle
	
#ifdef shadow_vsh
	#define position cameraPosition
#else
	#define position previousCameraPosition
#endif


// End of #include "/lib/EbinScript/Load.vsh"
