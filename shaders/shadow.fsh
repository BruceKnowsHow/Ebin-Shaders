#version 410 compatibility
#define gbuffers_shadow
#define fsh
#define ShaderStage -1
#include "/lib/Syntax.glsl"


uniform sampler2D texture;

varying vec4 color;
varying vec2 texcoord;

varying vec3 vertNormal;

#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"


void main() {
	vec4 diffuse = color * texture2D(texture, texcoord);
	
	diffuse.rgb *= pow(max0(vertNormal.z), 1.0 / 2.2);
	
	gl_FragData[0] = vec4(diffuse.rgb, diffuse.a);
	gl_FragData[1] = vec4(vertNormal.xy * 0.5 + 0.5, 0.0, 1.0);
}
