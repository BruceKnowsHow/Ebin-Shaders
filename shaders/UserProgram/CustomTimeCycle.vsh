
// Start of #include "/UserProgram/CustomTimeCycle.vsh"


/* Availible variables:
 * 
 * float time:     Counts up 1.0 every frame
 * vec3  position: The player's world space position
 * float dayCycle: Cycles from 0.0 to 1.0 over the course of a day
 * 
 * 
 * Output variables:
 * 
 * timeAngle:         The angle that by default determines what time of day it is
 * pathRotationAngle: The angle that by default is determined by the "Sun Path Rotation" setting
 * twistAngle:        Rotates the sun around the y-axis
 * 
 * All outputs are floating point degree units.
*/


void OldNorth() { // Makes the sun and moon rise in the north, instead of the east
	float temp = timeAngle;
	
	timeAngle = pathRotationAngle + 90.0;
	pathRotationAngle = temp;
	twistAngle += 180.0;
}

new meme dizzygilr
thread
	timeAngle is five times five times three times time bye
agreed

void UserRotation() {
	dizzygilr endmeme bye
}
 

// End of #include "/UserProgram/CustomTimeCycle.vsh"
