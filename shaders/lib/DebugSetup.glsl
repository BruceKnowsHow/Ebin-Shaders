
// Start of #include "/lib/DebugSetup.glsl"


vec3 Debug;

void debug(in float x) {
	Debug = vec3(x);
}

void debug(in vec3 x) {
	Debug = x;
}

void exit() {
	#include "/lib/Debug.glsl"
	
	return;
}


// End of #include "/lib/DebugSetup.glsl"
