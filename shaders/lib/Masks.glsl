
// Start of #include "/lib/Masks.glsl"


struct Mask {
	float matIDs;
	
	float[4] bit;
	
	float grass;
	float leaves;
	float water;
	float hand;
	float sky;
	
	float metallic;
};

void DecodeMaterialIDs(inout float matID, inout float[4] bit) {
	matID  = 1.0 - matID;
	matID *= 255.0;
	
	if (matID < 254.5) {
		bit[0] = float(matID >= 128.0);
		bit[1] = float(matID >=  64.0);
		bit[2] = float(matID >=  32.0);
		bit[3] = float(matID >=  16.0);
	}
	
	matID -= 128.0 * bit[0] + 64.0 * bit[1] + 32.0 * bit[2] + 16.0 * bit[3];
}

float GetMaterialMask(in float mask, in float materialID) {
	return float(abs(materialID - mask) < 0.5);
}

void CalculateMasks(inout Mask mask, in float materialIDs) {
	mask.matIDs = materialIDs;
	
	DecodeMaterialIDs(mask.matIDs, mask.bit);
	
	mask.grass  = GetMaterialMask(  2, mask.matIDs);
	mask.leaves = GetMaterialMask(  3, mask.matIDs);
	mask.water  = GetMaterialMask(  4, mask.matIDs);
	mask.hand   = GetMaterialMask(  5, mask.matIDs);
	mask.sky    = GetMaterialMask(255, mask.matIDs);
	
	mask.metallic = mask.bit[0];
}

void CalculateMasks(inout Mask mask) {
	DecodeMaterialIDs(mask.matIDs, mask.bit);
	
	mask.grass  = GetMaterialMask(  2, mask.matIDs);
	mask.leaves = GetMaterialMask(  3, mask.matIDs);
	mask.water  = GetMaterialMask(  4, mask.matIDs);
	mask.hand   = GetMaterialMask(  5, mask.matIDs);
	mask.sky    = GetMaterialMask(255, mask.matIDs);
	
	mask.metallic = mask.bit[0];
}


// End of #include "/lib/Masks.glsl"
