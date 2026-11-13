shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float motion_enabled=1.0;
void fragment() {
 float streak=pow(max(0.0,sin(UV.y*38.0-TIME*motion_enabled*5.0+sin(UV.x*14.0))),5.0);
 float edge=smoothstep(0.0,0.18,UV.x)*smoothstep(0.0,0.18,1.0-UV.x);
 ALBEDO=mix(vec3(0.14,0.35,0.34),vec3(0.67,0.86,0.81),streak*edge*0.22);
 EMISSION=vec3(0.13,0.31,0.29)*streak*0.15;
 ROUGHNESS=0.18;
}
