// Start of #include "/lib/Vertex/CalculateTBN.vsh"

/* Prerequisites:

attribute vec4 at_tangent;

// #include "/lib/VertexDisplacements.vsh"

*/


void CalculateTBN(in vec3 position, out mat3 tbnMatrix, out vec3 normal) {
	vec3 tangent  = normalize(                  at_tangent.xyz );
	vec3 binormal = normalize(-cross(gl_Normal, at_tangent.xyz));
	
	#ifdef RECALCULATE_DISPLACED_NORMALS
		tangent  += CalculateVertexDisplacements(position +  tangent) * 0.3;
		binormal += CalculateVertexDisplacements(position + binormal) * 0.3;
	#endif
	
	tangent  = normalize(gl_NormalMatrix * tangent);
	binormal = normalize(gl_NormalMatrix * binormal);
	
	normal = cross(-tangent, binormal);
	
	tbnMatrix = transpose(mat3(tangent, binormal, normal));
}

// End of #include "/lib/Vertex/CalculateTBN.vsh"