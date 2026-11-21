shader_type spatial;
render_mode cull_disabled;

// Complete leaf geometry only. No backing plane, vertical skirt or clearing clip.
uniform sampler2D leaf_map : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 leaf_shadow : source_color;
uniform vec4 leaf_midtone : source_color;
uniform vec4 leaf_highlight : source_color;
uniform float brightness = 1.0;
uniform float alpha_cutoff = 0.5;

void fragment() {
	vec4 leaf = texture(leaf_map, UV);
	float pigment = dot(leaf.rgb, vec3(0.299, 0.587, 0.114));
	vec3 foliage = mix(leaf_shadow.rgb, leaf_midtone.rgb, smoothstep(0.0, 0.5, pigment));
	foliage = mix(foliage, leaf_highlight.rgb, smoothstep(0.5, 1.0, pigment) * 0.6);
	ALBEDO = foliage * brightness;
	ALPHA = leaf.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;
	ROUGHNESS = 0.95;
	SPECULAR = 0.08;
}
