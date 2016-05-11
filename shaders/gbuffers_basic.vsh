#version 120
#define basic_vsh true
#define ShaderStage -10

varying vec3 color;

void main() {
	color = gl_Color.rgb;
	
	gl_Position	= ftransform();
}