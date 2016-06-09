#version 410 compatibility
#define gbuffers_skybasic
#define fsh
#define ShaderStage -1
#include "/lib/Syntax.glsl"

void main() {
	gl_FragData[0] = vec4(0.0, 0.0, 0.0, 1.0);
}