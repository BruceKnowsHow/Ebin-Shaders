// #include "/lib/Fragment/Masks.fsh"

struct Mask {
	float materialIDs;
	float matIDs;
	
	float[4] bit;
	
	float grass;
	float leaves;
	float water;
	float hand;
	float sky;
	
	float transparent;
	float metallic;
};

float EncodeMaterialIDs(in float materialIDs, in float bit0, in float bit1, in float bit2, in float bit3) {
	bit0 = float(bit0 > 0.5);
	bit1 = float(bit1 > 0.5);
	bit2 = float(bit2 > 0.5);
	bit3 = float(bit3 > 0.5);
	
	materialIDs += 128.0 * bit0;
	materialIDs +=  64.0 * bit1;
	materialIDs +=  32.0 * bit2;
	materialIDs +=  16.0 * bit3;
	
	materialIDs += 0.1;
	materialIDs /= 255.0;
	materialIDs  = 1.0 - materialIDs; // MaterialIDs are sent through the pipeline inverted so that when they're decoded, sky pixels (which are always written as 0.0 in certain situations) will be 1.0
	
	return materialIDs;
}

void DecodeMaterialIDs(inout float matID, out float[4] bit) {
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

Mask CalculateMasks(in Mask mask) {
	mask.matIDs = mask.materialIDs;
	
	DecodeMaterialIDs(mask.matIDs, mask.bit);
	
	mask.grass  = GetMaterialMask(  2, mask.matIDs);
	mask.leaves = GetMaterialMask(  3, mask.matIDs);
	mask.water  = GetMaterialMask(  4, mask.matIDs);
	mask.hand   = GetMaterialMask(  5, mask.matIDs);
	mask.sky    = GetMaterialMask(255, mask.matIDs);
	
	mask.transparent = mask.bit[0];
	mask.metallic    = mask.bit[1];
	
	return mask;
}

Mask AddWaterMask(in Mask mask, in float depth, in float depth1) {
	mask.water = float(depth != depth1 && mask.transparent < 0.5);
	
	if (mask.water > 0.5) mask.matIDs = 4.0;
	
	mask.materialIDs = EncodeMaterialIDs(mask.matIDs, mask.bit[0], mask.bit[1], mask.bit[2], mask.bit[3]);
	
	return mask;
}
