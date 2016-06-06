
// Start of #include "/lib/Debug.glsl"

//            Drawbuffers | ShaderStage | Primary Passthrough Stage?
// 
// gbuffers_textured_lit: 2306 | -1 | 
// composite:             4    |  0 | No
// composite1:            24   |  1 | Yes
// composite2:            0    |  2 | Yes
// composite3:            2    |  3 | No
// final:                      |  7 | Yes
//                        0123 <-- Reassignment order


#ifdef DEBUG
	#if ShaderStage == DEBUG_VIEW
		#if ShaderStage == -1
			gl_FragData[1] = vec4(pow(Debug * DEBUG_MULTIPLYER, vec3(DEBUG_CURVE)), 1.0);
		#else
			gl_FragData[0] = vec4(pow(Debug * DEBUG_MULTIPLYER, vec3(DEBUG_CURVE)), 1.0);
		#endif
		
	#elif ShaderStage > DEBUG_VIEW
		#if   ShaderStage == 0
			discard;
			
		#elif ShaderStage == 1
			#if DEBUG_VIEW != 0
				gl_FragData[0] = vec4(texture2D(colortex2, texcoord).rgb, 1.0);
			#else
				gl_FragData[0] = vec4(texture2D(colortex4, texcoord).rgb, 1.0);
			#endif
			
		#elif ShaderStage == 2
			gl_FragData[0] = vec4(texture2D(colortex2, texcoord).rgb, 1.0);
			
		#elif ShaderStage == 3
			discard;
			
		#elif ShaderStage == 7
			#if DEBUG_VIEW != 3
				gl_FragData[0] = vec4(texture2D(colortex1, texcoord).rgb, 1.0);
			#else
				gl_FragData[0] = vec4(texture2D(colortex2, texcoord).rgb, 1.0);
			#endif
			
		#endif
	#endif
#endif


// End of #include "/lib/Debug.glsl"
