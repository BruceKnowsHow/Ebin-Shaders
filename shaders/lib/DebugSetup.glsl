
// Start of #include "/lib/DebugSetup.glsl"


varying vec3 vDebug;
vec3 Debug;


#if defined vsh
	#define Debug vDebug
#endif

void debug(in bool x) {
	Debug = vec3(float(x));
}

void debug(in float x) {
	Debug = vec3(x);
}

void debug(in vec2 x) {
	Debug = vec3(length(x));
}

void debug(in vec3 x) {
	Debug = x;
}

void debug(in vec4 x) {
	Debug = x.rgb;
}

#if defined vsh
	#undef Debug
#endif


#define show debug    // debug() and show() can be used interchangeably

void exit() {
	Debug = max(Debug, vDebug);
	
	#include "/lib/Debug.glsl"
}


// End of #include "/lib/DebugSetup.glsl"
