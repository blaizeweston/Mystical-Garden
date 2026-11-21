shader_type spatial;
render_mode world_vertex_coords, cull_disabled;

// 0: forest mass, 1: top crowns, 2: inner skirt, 3: lower foliage fringe.
uniform int layer = 0;
uniform sampler2D leaf_map : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D garden_perimeter : filter_nearest, repeat_enable;
uniform float garden_reveal = 1.0;
uniform vec4 leaf_shadow : source_color;
uniform vec4 leaf_midtone : source_color;
uniform vec4 leaf_highlight : source_color;
uniform vec4 undergrowth : source_color;
uniform vec4 bark_shadow : source_color;
uniform float canopy_height = 2.6;
uniform float foreground_ratio = 0.64;
uniform float height_variation = 0.23;
uniform float edge_inset = 0.13;
uniform float leaf_overhang = 0.65;
uniform float alpha_cutoff = 0.5;

varying vec3 world_position;

float height_at(vec2 p) {
	vec2 heading = normalize(p + vec2(0.0001));
	float foreground = smoothstep(0.18, 0.9, dot(heading, normalize(vec2(0.23, 0.973))));
	return canopy_height * mix(1.0, foreground_ratio, foreground)
		+ height_variation * sin(p.x * 0.47 + 0.8) * cos(p.y * 0.39);
}

float edge_radius(vec2 p) {
	float count = float(textureSize(garden_perimeter, 0).x);
	float sector = fract(atan(p.y, p.x + 0.00001) / TAU) * count;
	float index = floor(sector);
	float step_angle = TAU / count;
	float local_angle = fract(sector) * step_angle;
	vec2 first = texture(garden_perimeter, vec2((index + 0.5) / count, 0.5)).rg;
	vec2 second = texture(garden_perimeter, vec2((index + 1.5) / count, 0.5)).rg;
	float a = mix(first.r, first.g, garden_reveal);
	float b = mix(second.r, second.g, garden_reveal);
	// Same ray/chord intersection as terrain_natural.gdshader and the movement edge.
	return a * b * sin(step_angle) / max(b * sin(step_angle - local_angle) + a * sin(local_angle), 0.001);
}

void vertex() {
	if (layer == 2) {
		float angle = UV.x * TAU;
		vec2 direction = vec2(cos(angle), sin(angle));
		vec2 ends = texture(garden_perimeter, vec2(UV.x + 0.5 / float(textureSize(garden_perimeter, 0).x), 0.5)).rg;
		VERTEX.xz = direction * (mix(ends.r, ends.g, garden_reveal) + edge_inset);
		VERTEX.y = UV.y * height_at(VERTEX.xz) * 0.55;
	} else if (layer == 3) {
		VERTEX.y = (VERTEX.y + 0.52) * height_at(VERTEX.xz);
	} else {
		VERTEX.y += height_at(VERTEX.xz);
	}
	world_position = VERTEX;
}

void fragment() {
	float inset = layer == 1 || layer == 3 ? -leaf_overhang : edge_inset;
	if (layer != 2 && length(world_position.xz) < edge_radius(world_position.xz) + inset) {
		discard;
	}
	float broad = 0.5 + 0.5 * sin(world_position.x * 0.53 + sin(world_position.z * 0.37)) * cos(world_position.z * 0.49);
	vec3 foliage = mix(leaf_shadow.rgb, leaf_midtone.rgb, 0.35 + broad * 0.65);
	ALPHA = 1.0;
	if (layer == 1 || layer == 3) {
		vec4 leaf = texture(leaf_map, UV);
		float pigment = dot(leaf.rgb, vec3(0.299, 0.587, 0.114));
		foliage = mix(leaf_midtone.rgb, leaf_highlight.rgb, pigment * 0.65 + broad * 0.35);
		ALPHA = leaf.a;
	} else if (layer == 2) {
		float trunks = 0.5 + 0.5 * sin(world_position.x * 3.7 + world_position.z * 4.1);
		foliage = mix(bark_shadow.rgb, undergrowth.rgb, smoothstep(0.0, 0.65, UV.y));
		foliage *= 0.85 + trunks * 0.3;
		foliage = mix(foliage, leaf_shadow.rgb, smoothstep(0.65, 1.0, UV.y));
	}
	ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;
	ALBEDO = foliage;
	// A small diffuse lift keeps the dense forest mass readable under the fixed
	// Garden light, without making imported leaf cards glow above a black roof.
	EMISSION = foliage * (layer == 0 ? 0.65 : (layer == 2 ? 0.3 : 0.16));
	ROUGHNESS = 0.94;
	SPECULAR = 0.12;
}
