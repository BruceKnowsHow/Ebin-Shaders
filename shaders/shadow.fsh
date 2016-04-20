#version 120

uniform sampler2D texture;

varying vec4 color;
varying vec2 texcoord;

varying vec3 vertNormal;

void main() {
	vec4 diffuse  = color;
	     diffuse *= texture2D(texture, texcoord);
	
	float NdotL = dot(vertNormal, vec3(0.0, 0.0, 1.0));
	
	diffuse.rgb *= pow(NdotL, 1.0 / 2.2);
	
	
	gl_FragData[0] = vec4(1.0 - diffuse.rgb, diffuse.a);    // Diffuse is inverted here because sky pixels will always be written as RGB 1.0. If we invert everything when we read it, then sky pixels will all be RGB 0.0, and our colors will be unaffected
	gl_FragData[1] = vec4(vertNormal * 0.5 + 0.5, 1.0);
}