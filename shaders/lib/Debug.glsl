vec3 Debug;

#if ShaderStage < 0
	varying vec3 vDebug;
	
	#if ShaderStage == -2
		#define Debug vDebug
	#endif
#endif


void show(bool x) {
	Debug = vec3(float(x));
}

void show(float x) {
	Debug = vec3(x);
}

void show(vec2 x) {
	Debug = vec3(length(x));
}

void show(vec3 x) {
	Debug = x;
}

void show(vec4 x) {
	Debug = x.rgb;
}

#if ShaderStage == -2
	#undef Debug
#endif


void exit() {
#if ShaderStage < 0
	Debug = max(Debug, vDebug); // This will malfunction if you have a show() in both the vertex and fragment
#endif
	
	#ifdef DEBUG
		#if ShaderStage == DEBUG_VIEW
			#if ShaderStage == -1
				gl_FragData[3] = vec4(Debug, 1.0);
			#else
				gl_FragData[0] = vec4(Debug, 1.0);
			#endif
			
		#elif ShaderStage > DEBUG_VIEW
			#if   ShaderStage == 0
				discard;
				
			#elif ShaderStage == 1
				#if DEBUG_VIEW == 0
					gl_FragData[0] = vec4(texture2D(colortex6, texcoord * COMPOSITE0_SCALE).rgb, 1.0);
				#else
					gl_FragData[0] = vec4(texture2D(colortex3, texcoord).rgb, 1.0);
				#endif
				
			#elif ShaderStage == 2
				gl_FragData[0] = vec4(texture2D(colortex1, texcoord).rgb, 1.0);
				
			#elif ShaderStage == 3
				discard;
				
			#elif ShaderStage == 7
				#if DEBUG_VIEW != 3
					gl_FragData[0] = vec4(texture2D(colortex3, texcoord).rgb, 1.0);
				#else
					gl_FragData[0] = vec4(texture2D(colortex1, texcoord).rgb, 1.0);
				#endif
				
			#endif
		#endif
	#endif
}

#if (defined DEBUG && (defined composite0 || defined composite1))
	#define discard exit(); return
#endif
