#version 410 compatibility
#define gbuffers_skybasic
#define vsh
#define ShaderStage -10
#include "/lib/Syntax.glsl"


uniform mat4 gbufferModelView;
uniform mat4 shadowModelView;

uniform vec3 upPosition;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform float frameTimeCounter;
uniform float sunAngle;

varying vec3 color;
varying vec2 texcoord;

#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"
#include "/lib/ShadowViewMatrix.vsh"
#include "/lib/GlobalCompositeVariables.glsl"
#include "/lib/DebugSetup.glsl"


void main() {
	color    = gl_Color.rgb;
	texcoord = gl_MultiTexCoord0.st;
	
	gl_Position = ftransform();
	
	#include "/lib/CompositeCalculations.vsh"
	
	exit();
}