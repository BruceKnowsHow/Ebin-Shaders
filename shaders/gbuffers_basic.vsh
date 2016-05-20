#version 410 compatibility
#define gbuffers_basic
#define vsh
#define ShaderStage -10
#include "/lib/Compatibility.glsl"


varying vec3 color;

void main() {
	color = gl_Color.rgb;
	
	gl_Position	= ftransform();
}