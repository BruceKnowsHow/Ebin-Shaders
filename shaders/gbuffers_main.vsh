attribute vec4 mc_Entity;
attribute vec4 at_tangent;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

uniform vec3  cameraPosition;
uniform float frameTimeCounter;

varying vec3 color;
varying vec2 texcoord;

varying mat3 tbnMatrix;

varying mat2x3 position;

varying vec3 worldNormal;

varying vec2 vertLightmap;

varying float mcID;
varying float materialIDs;
varying float tbnIndex;

#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"
#include "/lib/Debug.glsl"
#include "/lib/Uniform/Projection_Matrices.vsh"

#if defined gbuffers_water
#include "/lib/Uniform/Shading_Variables.glsl"
#include "/lib/Uniform/Shadow_View_Matrix.vsh"
#endif


vec2 GetDefaultLightmap(vec2 lightmapCoord) { // Gets the lightmap from the default lighting engine, ignoring any texture pack lightmap. First channel is torch lightmap, second channel is sky lightmap.
	return clamp((lightmapCoord * pow2(1.031)) - 0.032, 0.0, 1.0).st; // Default lightmap texture coordinates work somewhat as lightmaps, however they need to be adjusted to use the full range of 0.0-1.0
}

#include "/lib/Vertex/Materials.vsh"

vec3 GetWorldSpacePosition() {
	return mat3(gbufferModelViewInverse) * transMAD(gl_ModelViewMatrix, gl_Vertex.xyz);
}

vec4 ProjectViewSpace(vec3 viewSpacePosition) {
#if !defined gbuffers_hand
	return vec4(projMAD(projMatrix, viewSpacePosition), viewSpacePosition.z * projMatrix[2].w);
#else
	return vec4(projMAD(gl_ProjectionMatrix, viewSpacePosition), viewSpacePosition.z * gl_ProjectionMatrix[2].w);
#endif
}

#include "/lib/Vertex/Waving.vsh"
#include "/lib/Vertex/Vertex_Displacements.vsh"

mat3 CalculateTBN(vec3 worldPosition, vec3 displacement) {
	vec3 tangent  = normalize(at_tangent.xyz);
	vec3 binormal = normalize(-cross(gl_Normal, at_tangent.xyz));
	
	tangent  += CalculateVertexDisplacements(worldPosition +  tangent, vertLightmap.g) - displacement;
	binormal += CalculateVertexDisplacements(worldPosition + binormal, vertLightmap.g) - displacement;
	
	tangent  = normalize(gl_NormalMatrix *  tangent);
	binormal = normalize(gl_NormalMatrix * binormal);
	
	vec3 normal = cross(-tangent, binormal);
	
	return mat3(tangent, binormal, normal);
}

float EncodePlanarTBN(vec3 worldSpaceNormal) { // Encode the TBN matrix into a 3-bit float
	// Only valid for axis-oriented TBN matrices
	
	float tbnIndex = 6.0; // Default is 6.0, which corresponds to an upward facing block, such as ocean
	
	cfloat sqrt2 = sqrt(2.0) * 0.5;
	
	if      (worldSpaceNormal.x >  sqrt2) tbnIndex = 1.0;
	else if (worldSpaceNormal.x < -sqrt2) tbnIndex = 2.0;
	else if (worldSpaceNormal.z >  sqrt2) tbnIndex = 3.0;
	else if (worldSpaceNormal.z < -sqrt2) tbnIndex = 4.0;
	else if (worldSpaceNormal.y < -sqrt2) tbnIndex = 5.0;
	
	return tbnIndex;
}

void main() {
	SetupProjection();
	
	color        = gl_Color.rgb;
	texcoord     = gl_MultiTexCoord0.st;
	mcID         = mc_Entity.x;
	vertLightmap = GetDefaultLightmap(mat2(gl_TextureMatrix[1]) * gl_MultiTexCoord1.st);
	materialIDs  = GetMaterialIDs(int(mc_Entity.x));
	tbnIndex     = EncodePlanarTBN(gl_Normal);
	
	vec3 worldSpacePosition = GetWorldSpacePosition();
	vec3 worldDisplacement  = CalculateVertexDisplacements(worldSpacePosition, vertLightmap.g);
	
	position[1] = worldSpacePosition + worldDisplacement;
	position[0] = mat3(gbufferModelView) * position[1];
	
	gl_Position = ProjectViewSpace(position[0]);
	
	
	worldNormal = mat3(gbufferModelViewInverse) * gl_NormalMatrix * normalize(gl_Normal);
	tbnMatrix   = CalculateTBN(worldSpacePosition, worldDisplacement);
	
	
#if defined gbuffers_water
	#include "/lib/Vertex/Shading_Setup.vsh"
#endif
	
#if defined gbuffers_spidereyes
	gl_Position.z += 0.0001 * sign(dot(position[0], tbnMatrix[2])); // Stop flicker
#endif
	
	
	exit();
}
