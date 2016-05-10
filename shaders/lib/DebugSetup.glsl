
// Start of #include "/lib/DebugSetup.glsl"


vec3 Debug;

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

#define show debug    // debug() and show() can be used interchangeably

void exit() {
	#include "/lib/Debug.glsl"
	
	return;
}


// End of #include "/lib/DebugSetup.glsl"
