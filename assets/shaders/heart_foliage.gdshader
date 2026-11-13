shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform float motion_enabled=1.0;
uniform vec3 player_world_position=vec3(10000.0,1.0,0.0);
varying vec3 leaf_view_position;
void vertex(){
 vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 VERTEX.x+=sin(world.x*.7+world.z*.6+TIME*1.1)*UV.y*.025*motion_enabled;
 leaf_view_position=(MODELVIEW_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment(){
 float vein=pow(max(0.0,1.0-abs(UV.x-.5)*18.0),3.0);
 ALBEDO=COLOR.rgb*(.9+vein*.16);ROUGHNESS=.86;SPECULAR=.08;
 vec3 player_view=(VIEW_MATRIX*vec4(player_world_position,1.0)).xyz;
 float obscures=(1.0-smoothstep(.4,1.0,length(leaf_view_position.xy-player_view.xy)))*step(player_view.z,leaf_view_position.z);
 ALPHA=.82*(1.0-obscures*.85);
}
