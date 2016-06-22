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
	vec4 diffuse  = color;
	     diffuse *= texture2D(texture, texcoord);
	
	float NdotL = max0(dot(vertNormal, vec3(0.0, 0.0, 1.0)));
	
	diffuse.rgb *= pow(NdotL, 1.0 / 2.2);
	
	vec3 shadowNormal = vertNormal;
	
	gl_FragData[0] = vec4(diffuse.rgb, diffuse.a);
	gl_FragData[1] = vec4(shadowNormal.xy * 0.5 + 0.5, 0.0, 1.0);
}
