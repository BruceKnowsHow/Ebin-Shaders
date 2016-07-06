#if defined fsh
	#define varying in
#endif

#if defined vsh
	#define attribute in
	#define varying out
#endif

//#define DEBUG

#define cbool  const bool
#define cuint  const uint
#define cint   const int
#define cfloat const float
#define cvec2  const vec2
#define cvec3  const vec3
#define cvec4  const vec4
