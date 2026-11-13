shader_type spatial;
render_mode unshaded,cull_disabled;
uniform float motion_enabled=1.0;
void vertex() {
 float phase=INSTANCE_CUSTOM.r*6.283185;
 float clock=TIME*motion_enabled;
 float angle=clock*(0.3+INSTANCE_CUSTOM.g*0.12)+phase;
 float flap=sin(clock*36.0+phase)*0.9;
 VERTEX.y+=abs(VERTEX.x)*flap;
 vec2 rotated=mat2(vec2(cos(angle),-sin(angle)),vec2(sin(angle),cos(angle)))*VERTEX.xz;
 VERTEX.xz=rotated+vec2(cos(angle),sin(angle*1.3+phase))*(0.65+INSTANCE_CUSTOM.g*1.2);
 VERTEX.y+=sin(clock*1.7+phase)*0.16;
}
void fragment() {
 float fleck=sin(UV.x*64.0)*sin(UV.y*37.0)*0.5+0.5;
 ALBEDO=mix(vec3(0.52,0.49,0.30),vec3(0.91,0.87,0.67),0.65+fleck*0.15);
}
