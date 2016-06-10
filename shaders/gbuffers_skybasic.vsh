#version 410 compatibility
#define gbuffers_skybasic
#define vsh
#define ShaderStage -2
#include "/lib/Syntax.glsl"

void main() {
	gl_Position = ftransform();
}