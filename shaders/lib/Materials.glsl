
// Start of #include "/lib/Materials.vsh"


float GetMaterialIDs(in int mc_ID) { // Gather material masks
	float materialID;
	
	switch(mc_ID) {
		case 31:                     // Tall Grass
		case 37:                     // Dandelion
		case 38:                     // Rose
		case 59:                     // Wheat
		case 83:                     // Sugar Cane
		case 175:                    // Double Tall Grass
			materialID = 2.0; break; // Grass
		case 18:                     // Generic leaves
		case 106:                    // Vines
		case 161:                    // New leaves
			materialID = 3.0; break; // Leaves
		case 8:
		case 9:
			materialID = 4.0; break; // Water
		case 79:
			materialID = 5.0; break; // Ice
		default:
			materialID = 1.0;
	}
	
	return materialID;
}

float EncodeMaterialIDs(in float materialIDs, in float bit0, in float bit1, in float bit2, in float bit3) {
	materialIDs += 128.0 * bit0;
	materialIDs +=  64.0 * bit1;
	materialIDs +=  32.0 * bit2;
	materialIDs +=  16.0 * bit3;
	
	materialIDs += 0.1;
	materialIDs /= 255.0;
	materialIDs  = 1.0 - materialIDs; // MaterialIDs are sent through the pipeline inverted so that when they're decoded, sky pixels (which are always written as 0.0 in certain situations) will be 1.0
	
	return materialIDs;
}


// End of #include "/lib/Materials.vsh"
