float GetMaterialIDs(int mc_ID) { // Gather material masks
#if defined gbuffers_hand
	return 5.0;
#endif
	
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
		default:
			materialID = 1.0;
	}
	
	return materialID;
}
