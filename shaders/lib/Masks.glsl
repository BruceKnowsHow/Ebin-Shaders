struct Mask {
	float materialIDs;
	float matIDs;
	
	float bit0;
	float bit1;
	float bit2;
	float bit3;
	
	float grass;
	float leaves;
	float water;
	float sky;
};

void DecodeMaterialIDs(inout float matID, inout float bit0, inout float bit1, inout float bit2, inout float bit3) {
	matID  = 1.0 - matID;
	matID *= 255.0;
	
	if (matID >= 128.0 && matID < 254.5) {
		matID -= 128.0;
		bit0 = 1.0;
	}
	
	if (matID >= 64.0 && matID < 254.5) {
		matID -= 64.0;
		bit1 = 1.0;
	}
	
	if (matID >= 32.0 && matID < 254.5) {
		matID -= 32.0;
		bit2 = 1.0;
	}
	
	if (matID >= 16.0 && matID < 254.5) {
		matID -= 16.0;
		bit3 = 1.0;
	}
}

float GetMaterialMask(in float mask, in float materialID) {
	return float(abs(materialID - mask) < 0.1);
}

void CalculateMasks(inout Mask mask, in float materialIDs, const bool encoded) {
	mask.materialIDs = materialIDs;
	mask.matIDs      = mask.materialIDs;
	
	if (encoded) DecodeMaterialIDs(mask.matIDs, mask.bit0, mask.bit1, mask.bit2, mask.bit3);
	
	mask.grass  = GetMaterialMask(  2, mask.matIDs);
	mask.leaves = GetMaterialMask(  3, mask.matIDs);
	mask.water  = GetMaterialMask(  4, mask.matIDs);
	mask.sky    = GetMaterialMask(255, mask.matIDs);
}