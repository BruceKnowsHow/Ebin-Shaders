// #include "/lib/DebugSetup.glsl"

vec3 Debug;

#if ShaderStage < 0
	varying vec3 vDebug;
	
	#if ShaderStage == -2
		#define Debug vDebug
	#endif
#endif


void show(in bool x) {
	Debug = vec3(float(x));
}

void show(in float x) {
	Debug = vec3(x);
}

void show(in vec2 x) {
	Debug = vec3(length(x));
}

void show(in vec3 x) {
	Debug = x;
}

void show(in vec4 x) {
	Debug = x.rgb;
}

#if ShaderStage == -2
	#undef Debug
#endif


void exit() {
#if ShaderStage < 0
	Debug = max(Debug, vDebug); // This will malfunction if you have a show() in both the vertex and fragment
#endif
	
	#include "/lib/Debug.glsl"
}
