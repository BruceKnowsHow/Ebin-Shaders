#version 410 compatibility
#define final
#define vsh
#define ShaderStage 10
#include "/lib/Syntax.glsl"

#include "/lib/DebugSetup.glsl"

varying vec2 texcoord;

void main() {
	texcoord    = gl_MultiTexCoord0.st;
	gl_Position = ftransform();
	
	exit();
}