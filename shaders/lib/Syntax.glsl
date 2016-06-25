#if defined fsh
	#define varying in
#endif

#if defined vsh
	#define attribute in
	#define varying out
#endif

//#define DEBUG

#if (defined DEBUG && (defined composite0 || defined composite1))
	#define discard exit(); return
#endif


#define cbool  const bool
#define cuint  const uint
#define cint   const int
#define cfloat const float
#define cvec2  const vec2
#define cvec3  const vec3
#define cvec4  const vec4


// In-built function overrides
#define length(x) sqrt(dot(x, x))
