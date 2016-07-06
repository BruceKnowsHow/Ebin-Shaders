#version 410 compatibility
#define gbuffers_water
#define vsh
#define ShaderStage -2
#include "/lib/Syntax.glsl"


uniform mat4 shadowModelView;


#include "gbuffers_main.vsh"