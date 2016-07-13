#version 410 compatibility
#define gbuffers_water
#define vsh
#define ShaderStage -2
#include "/lib/Syntax.glsl"


uniform mat4 shadowModelView;

uniform vec3 upPosition;
uniform vec3 previousCameraPosition;

uniform float sunAngle;


#include "gbuffers_main.vsh"