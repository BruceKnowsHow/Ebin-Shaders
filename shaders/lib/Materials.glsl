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

// End of #include "/lib/Materials.vsh"