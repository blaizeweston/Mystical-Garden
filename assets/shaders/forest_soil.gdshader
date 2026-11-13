shader_type spatial;
render_mode cull_disabled;
uniform bool forest_bed=false;
uniform vec3 biome_tint=vec3(1.);
uniform float corruption=0.;
varying vec3 world;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){vec2 p=world.xz;float broad=noise(p*.4);float grain=noise(p*24.0);float damp=noise(p*2.1);vec3 dry=vec3(.24,.19,.125);vec3 wet=vec3(.105,.092,.064);vec3 col=mix(wet,dry,broad*.65+damp*.2);col*=.88+grain*.24;if(forest_bed){col=mix(vec3(.035,.045,.024),vec3(.087,.074,.040),broad);col*=.70+grain*.35;}ALBEDO=col*biome_tint*(1.-corruption*.18);ROUGHNESS=.95;NORMAL_MAP=vec3(.5+dFdx(grain)*.12,.5+dFdy(grain)*.12,1.0);NORMAL_MAP_DEPTH=.35;}
