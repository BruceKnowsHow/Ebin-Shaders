#version 120
#define skytextured_fsh true
#define ShaderStage -1

/* DRAWBUFFERS:2 */

uniform sampler2D texture;

varying vec3 color;
varying vec2 texcoord;

#include "/lib/Settings.glsl"
#include "/lib/Util.glsl"


void main() { discard;
	vec4 diffuse      = texture2D(texture, texcoord);
	     diffuse.rgb *= color;
	
	gl_FragData[0] = vec4(EncodeColor(diffuse.rgb), diffuse.a);
}