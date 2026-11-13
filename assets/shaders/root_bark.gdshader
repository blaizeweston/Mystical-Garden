shader_type spatial;
render_mode cull_disabled;
varying vec3 world;
float h(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float n(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x),f.y);}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){float grain=n(vec2(UV.x*4.0,UV.y*38.0));float ridge=pow(abs(sin(UV.y*95.0+n(vec2(UV.x*2.0,UV.y*9.0))*3.5)),.4);float patch=n(world.xz*4.0);ALBEDO=mix(vec3(.045,.030,.015),vec3(.21,.145,.070),ridge*.65+grain*.22);ALBEDO=mix(ALBEDO,vec3(.085,.105,.045),smoothstep(.65,.9,patch)*.3);ROUGHNESS=.96;NORMAL_MAP=vec3(.5+dFdx(grain)*.2,.5+dFdy(ridge)*.18,1);NORMAL_MAP_DEPTH=.65;}
