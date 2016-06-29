struct Mask {
	float materialIDs;
	float matIDs;
	
	float[4] bit;
	
	float grass;
	float leaves;
	float water;
	float hand;
	
	float metallic;
	float transparent;
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
	
	return materialIDs;
}

void DecodeMaterialIDs(inout float matID, out float[4] bit) {
	matID *= 255.0;
	
	bit[0] = float(matID >= 128.0);
	matID -= bit[0] * 128.0;
	
	bit[1] = float(matID >=  64.0);
	matID -= bit[1] * 64.0;
	
	bit[2] = float(matID >=  32.0);
	matID -= bit[2] * 32.0;
	
	bit[3] = float(matID >=  16.0);
	matID -= bit[3] * 16.0;
}

float GetMaterialMask(in float mask, in float materialID) {
	return float(abs(materialID - mask) < 0.5);
}

Mask CalculateMasks(in Mask mask) {
	mask.matIDs = mask.materialIDs;
	
	DecodeMaterialIDs(mask.matIDs, mask.bit);
	
	mask.grass  = GetMaterialMask(2, mask.matIDs);
	mask.leaves = GetMaterialMask(3, mask.matIDs);
	mask.hand   = GetMaterialMask(5, mask.matIDs);
	
	mask.metallic    = mask.bit[0];
	mask.transparent = mask.bit[1];
	mask.water       = mask.bit[2];
	
	return mask;
}

Mask AddWaterMask(in Mask mask, in float depth0, in float depth1) {
	mask.water = float(depth0 != depth1);
	mask.bit[2] = mask.water;
	
	mask.materialIDs = EncodeMaterialIDs(mask.matIDs, mask.bit[0], mask.bit[1], mask.bit[2], mask.bit[3]);
	
	return mask;
}
