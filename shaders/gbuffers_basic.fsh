#version 410 compatibility
#define gbuffers_basic
#define fsh
#define ShaderStage -1
#include "/lib/Compatibility.glsl"


/* DRAWBUFFERS:2 */

varying vec3 color;

void main() {
	gl_FragData[0] = vec4(color.rgb, 1.0);
}