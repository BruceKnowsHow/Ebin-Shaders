#version 120
#define final_vsh true
#define ShaderStage 10

varying vec2 texcoord;

void main() {
	texcoord    = gl_MultiTexCoord0.st;
	gl_Position = ftransform();
}