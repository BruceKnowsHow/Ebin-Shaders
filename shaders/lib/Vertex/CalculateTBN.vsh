void CalculateTBN(in vec3 position, out mat3 tbnMatrix) {
	vec3 tangent  = at_tangent.xyz;
	vec3 binormal = -cross(gl_Normal, at_tangent.xyz);
	
	tangent  = normalize(gl_NormalMatrix * tangent);
	binormal = normalize(gl_NormalMatrix * binormal);
	
	vec3 normal = cross(-tangent, binormal);
	
	tbnMatrix = transpose(mat3(tangent, binormal, normal));
}
