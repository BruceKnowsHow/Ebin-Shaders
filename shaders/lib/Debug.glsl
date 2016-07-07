//    ShaderStage | Primary Passthrough Stage?
//
// gbuffers  : -1 | 
// composite :  0 | No
// composite1:  1 | Yes
// composite2:  2 | Yes
// composite3:  3 | No
// final:       7 | Yes


#ifdef DEBUG
	#if ShaderStage == DEBUG_VIEW
		#if ShaderStage == -1
			gl_FragData[5] = vec4(Debug, 1.0);
		#else
			gl_FragData[0] = vec4(Debug, 1.0);
		#endif
		
	#elif ShaderStage > DEBUG_VIEW
		#if   ShaderStage == 0
			discard;
			
		#elif ShaderStage == 1
			#if DEBUG_VIEW != 0
				gl_FragData[0] = vec4(texture2D(colortex5, texcoord).rgb, 1.0);
			#else
				gl_FragData[0] = vec4(texture2D(colortex7, texcoord).rgb, 1.0);
			#endif
			
		#elif ShaderStage == 2
			gl_FragData[0] = vec4(texture2D(colortex5, texcoord).rgb, 1.0);
			
		#elif ShaderStage == 3
			discard;
			
		#elif ShaderStage == 7
			#if DEBUG_VIEW != 3
				gl_FragData[0] = vec4(texture2D(colortex3, texcoord).rgb, 1.0);
			#else
				gl_FragData[0] = vec4(texture2D(colortex5, texcoord).rgb, 1.0);
			#endif
			
		#endif
	#endif
#endif
