#include "/../shaders/lib/Syntax.glsl"


varying vec2 texcoord;

#include "/../shaders/lib/Uniform/Shading_Variables.glsl"


/***********************************************************************/
#if defined vsh

uniform sampler3D colortex7;

uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform float sunAngle;
uniform float far;

#include "/../shaders/lib/Settings.glsl"
#include "/../shaders/lib/Utility.glsl"
#include "/../shaders/lib/Debug.glsl"
#include "/../shaders/lib/Uniform/Projection_Matrices.vsh"
#include "/../shaders/UserProgram/centerDepthSmooth.glsl"
#include "/../shaders/lib/Uniform/Shadow_View_Matrix.vsh"
#include "/../shaders/lib/Fragment/PrecomputedSky.glsl"
#include "/../shaders/lib/Vertex/Shading_Setup.vsh"

void main() {
	texcoord    = gl_MultiTexCoord0.st;
	gl_Position = ftransform();
	
	SetupProjection();
	SetupShading();
}

#endif
/***********************************************************************/



/***********************************************************************/
#if defined fsh

#include "/../shaders/lib/Settings.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler3D colortex7;

#if defined COMPOSITE0_ENABLED
const bool colortex5MipmapEnabled = true;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
#endif

uniform sampler2D gdepthtex;
uniform sampler2D depthtex1;
uniform sampler2D noisetex;
uniform sampler2D shadowtex1;
uniform sampler2DShadow shadow;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;

uniform vec3 cameraPosition;
uniform vec3 upPosition;

uniform vec2 pixelSize;

uniform float viewWidth;
uniform float viewHeight;
uniform float wetness;
uniform float rainStrength;
uniform float nightVision;
uniform float near;
uniform float far;

uniform ivec2 eyeBrightnessSmooth;

uniform int isEyeInWater;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;

#include "/../shaders/lib/Utility.glsl"
#include "/../shaders/lib/Debug.glsl"
#include "/../shaders/lib/Uniform/Projection_Matrices.fsh"
#include "/../shaders/lib/Uniform/Shadow_View_Matrix.fsh"
#include "/../shaders/lib/Fragment/Masks.fsh"

#include "/../shaders/UserProgram/centerDepthSmooth.glsl" // Doesn't seem to be enabled unless it's initialized in a fragment.

vec3 GetDiffuse(vec2 coord) {
	return texture2D(colortex1, coord).rgb;
}

float GetDepth(vec2 coord) {
	return texture2D(gdepthtex, coord).x;
}

float GetTransparentDepth(vec2 coord) {
	return texture2D(depthtex1, coord).x;
}

float ExpToLinearDepth(float depth) {
	return 2.0 * near * (far + near - depth * (far - near));
}

vec3 CalculateViewSpacePosition(vec3 screenPos) {
	screenPos = screenPos * 2.0 - 1.0;
	
	return projMAD(projInverseMatrix, screenPos) / (screenPos.z * projInverseMatrix[2].w + projInverseMatrix[3].w);
}

#include "/../shaders/lib/Fragment/ComputeShadedFragment.fsh"
#include "/../shaders/lib/Fragment/BilateralUpsample.fsh"

#include "/../shaders/lib/Misc/CalculateFogfactor.glsl"
#include "/../shaders/lib/Fragment/WaterDepthFog.fsh"

/* DRAWBUFFERS:1465 */
#include "/../shaders/lib/Exit.glsl"

void main() {
	vec2 texure4 = ScreenTex(colortex4).rg;
	
	vec4  decode4       = Decode4x8F(texure4.r);
	Mask  mask          = CalculateMasks(decode4.r);
	float smoothness    = decode4.g;
	float torchLightmap = decode4.b;
	float skyLightmap   = decode4.a;
	
	float depth0 = (mask.hand > 0.5 ? 0.9 : GetDepth(texcoord));
	
	vec3 wNormal = DecodeNormal(texure4.g, 11);
	vec3 normal  = wNormal * mat3(gbufferModelViewInverse);
	
	float depth1 = mask.hand > 0.5 ? depth0 : GetTransparentDepth(texcoord);
	
	if (depth0 != depth1) {
		vec2 texure0 = texture2D(colortex0, texcoord).rg;
		
		vec4 decode0 = Decode4x8F(texure0.r);
		
		mask.transparent = 1.0;
		mask.water       = decode0.b;
		mask.bits.xy     = vec2(mask.transparent, mask.water);
		mask.materialIDs = EncodeMaterialIDs(1.0, mask.bits);

		texure4 = vec2(Encode4x8F(vec4(mask.materialIDs, decode0.r, 0.0, decode0.g)), texure0.g);
	}
	
	vec4 GI; vec2 VL;
	BilateralUpsample(wNormal, depth1, GI, VL);
	
	gl_FragData[1] = vec4(texure4.rg, 0.0, 1.0);
	gl_FragData[2] = vec4(VL.xy, 0.0, 1.0);
	
	
	mat2x3 backPos;
	backPos[0] = CalculateViewSpacePosition(vec3(texcoord, depth1));
	backPos[1] = mat3(gbufferModelViewInverse) * backPos[0];
	
	if (depth1 - mask.hand >= 1.0) { exit(); return; }
	
	
	vec3 diffuse = GetDiffuse(texcoord);
	vec3 viewSpacePosition0 = CalculateViewSpacePosition(vec3(texcoord, depth0));
	
	
	vec3 composite = ComputeShadedFragment(powf(diffuse, 2.2), mask, torchLightmap, skyLightmap, GI, normal, smoothness, backPos);
	
	gl_FragData[0] = vec4(max0(composite), 1.0);
	
	exit();
}

#endif
/***********************************************************************/
