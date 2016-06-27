struct Mask {
	float materialIDs;
	float matIDs;
	
	float[4] bit;
	
	float grass;
	float leaves;
	float hand;
	
	float metallic;
	
	float transparent;
	float water;
	float midGlass;
	float midWater;
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
		matID -= bit[0] * 128.0;
		
		bit[1] = float(matID >=  64.0);
		matID -= bit[1] * 64.0;
		
		bit[2] = float(matID >=  32.0);
		matID -= bit[2] * 32.0;
		
		bit[3] = float(matID >=  16.0);
		matID -= bit[3] * 16.0;
	}
}

float GetMaterialMask(in float mask, in float materialID) {
	return float(abs(materialID - mask) < 0.5);
}

Mask CalculateMasks(in Mask mask) {
	mask.matIDs = mask.materialIDs;
	
	DecodeMaterialIDs(mask.matIDs, mask.bit);
	
	mask.grass  = GetMaterialMask(  1, mask.matIDs);
	mask.leaves = GetMaterialMask(  2, mask.matIDs);
	mask.hand   = GetMaterialMask(  3, mask.matIDs);
	
	mask.metallic    = mask.bit[0];
	
	return mask;
}


#if ShaderStage >= 0 && ShaderStage < 7
Mask AddWaterMask(in Mask mask) {
	mask.transparent = texture2D(colortex6, texcoord).r;
	mask.water = texture2D(colortex6, texcoord).r;
	mask.midGlass = texture2D(colortex6, texcoord).r;
	mask.midWater = texture2D(colortex6, texcoord).r;
	
	return mask;
}
#endif
