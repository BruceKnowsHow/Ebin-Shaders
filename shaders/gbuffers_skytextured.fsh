#version 120
#define skytextured_fsh true
#define ShaderStage -1

/* DRAWBUFFERS:23 */

uniform sampler2D texture;

varying vec3 color;
varying vec2 texcoord;

void main() {
	vec4 diffuse      = texture2D(texture, texcoord);
	     diffuse.rgb *= color;
	
	gl_FragData[0] = vec4(diffuse.rgb, diffuse.a);
	gl_FragData[1] = vec4(0.0, 0.0, 0.0, 1.0);
}