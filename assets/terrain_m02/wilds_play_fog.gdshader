shader_type canvas_item;

uniform sampler2D explored : filter_linear, repeat_disable;
uniform vec2 world_min;
uniform vec2 world_size;
uniform vec2 screen_origin;
uniform vec2 screen_across;
uniform vec2 screen_down;

void fragment() {
	vec2 ground = screen_origin + UV.x * screen_across + UV.y * screen_down;
	vec2 map_uv = (ground - world_min) / world_size;
	float discovered = 0.0;
	if (all(greaterThanEqual(map_uv, vec2(0.0))) && all(lessThanEqual(map_uv, vec2(1.0)))) {
		discovered = texture(explored, map_uv).r;
	}
	COLOR = vec4(0.022, 0.033, 0.035, 1.0 - smoothstep(0.13, 0.87, discovered));
}
