
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
	#if ShaderStage == STAGE_VIEW
		#if   ShaderStage != 7
			gl_FragData[0] = vec4(Debug, 1.0);
		#else
			gl_FragColor   = vec4(Debug, 1.0);
		#endif
	#elif ShaderStage > STAGE_VIEW
		#if   ShaderStage == 0
			discard;
			
		#elif ShaderStage == 1
			#if STAGE_VIEW != 0
				gl_FragData[0] = vec4(texture2D(colortex2, texcoord).rgb, 1.0);
			#else
				gl_FragData[0] = vec4(texture2D(colortex4, texcoord).rgb, 1.0);
			#endif
			
		#elif ShaderStage == 2
			gl_FragData[0] = vec4(texture2D(colortex2, texcoord).rgb, 1.0);
			
		#elif ShaderStage == 3
			discard;
			
		#elif ShaderStage == 7
			#if STAGE_VIEW != 3
				gl_FragColor   = vec4(pow(texture2D(colortex0, texcoord).rgb * DEBUG_MULTIPLYER, vec3(DEBUG_CURVE)), 1.0);
			#else
				gl_FragColor   = vec4(pow(texture2D(colortex2, texcoord).rgb * DEBUG_MULTIPLYER, vec3(DEBUG_CURVE)), 1.0);
			#endif
			
		#endif
	#endif
#endif


// End of #include "/lib/Debug.glsl"
