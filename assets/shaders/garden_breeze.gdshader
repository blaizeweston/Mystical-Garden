shader_type spatial;
render_mode cull_disabled;
uniform float motion_enabled=1.0;
uniform float strength=0.065;
void vertex() {
 vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float weight=pow(clamp(VERTEX.y/0.5,0.0,1.0),2.0);
 float gust=sin(world.x*0.7+world.z*0.4+TIME*1.15)+0.3*sin(world.z*1.8-TIME*1.7);
 VERTEX.xz+=vec2(0.85,0.36)*gust*strength*weight*motion_enabled;
}
void fragment() {ALBEDO=COLOR.rgb;ROUGHNESS=0.98;SPECULAR=0.05;}
