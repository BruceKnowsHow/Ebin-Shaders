#version 120
#define basic_fsh true
#define ShaderStage -1

/* DRAWBUFFERS:2 */

varying vec3 color;

void main() {
	gl_FragData[0] = vec4(color.rgb, 1.0);
}