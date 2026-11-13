shader_type canvas_item;
render_mode unshaded;

uniform sampler2D bark : filter_linear, repeat_disable;
uniform float health : hint_range(0.0, 1.0) = 1.0;
uniform float capacity : hint_range(0.0, 1.0) = 1.0;
uniform float previous : hint_range(0.0, 1.0) = 1.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;

float surface(vec2 p, float level, float time) {
	float swell = sin(p.x * 6.0 - time * 1.6) * 0.025;
	swell += sin(p.x * 11.0 + time * 1.25) * 0.009;
	return 1.0 - 2.0 * level + swell * smoothstep(0.0, 0.15, min(level, 1.0 - level));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float pixel = max(fwidth(r), 0.002);
	float t = TIME;
	vec2 glass = p / 0.80;
	float liquid_y = surface(glass, health, t);
	float wet = smoothstep(liquid_y - pixel, liquid_y + pixel, glass.y);
	float gold_line_y = 1.0 - capacity * 2.0;
	float seal = 1.0 - smoothstep(gold_line_y - pixel, gold_line_y + pixel, glass.y);

	vec3 empty = mix(vec3(0.045, 0.016, 0.021), vec3(0.14, 0.047, 0.055), clamp(glass.y + 0.65, 0.0, 1.0));
	empty = mix(empty, vec3(0.036, 0.030, 0.026), seal * step(capacity, 0.999) * 0.85);

	float depth = clamp((glass.y - liquid_y) * 0.52, 0.0, 1.0);
	float current = sin(glass.y * 12.0 + sin(glass.x * 4.5 + t * 0.8) * 1.7 - t * 0.9);
	current += sin(glass.y * 22.0 - glass.x * 5.0 + t * 1.1) * 0.32;
	float glow = exp(-2.3 * dot(glass - vec2(-0.25, -0.34), glass - vec2(-0.25, -0.34)));
	vec3 red = mix(vec3(0.66, 0.073, 0.111), vec3(0.23, 0.015, 0.035), depth);
	red += vec3(0.12, 0.047, 0.046) * glow;
	red += vec3(0.039, 0.016, 0.020) * current * (0.45 + 0.55 * glow);
	float meniscus = exp(-abs(glass.y - liquid_y) * 39.0) * step(0.001, health) * (1.0 - step(0.999, health));
	red += vec3(0.29, 0.12, 0.11) * meniscus;

	float old_wet = smoothstep(surface(glass, previous, t) - pixel, surface(glass, previous, t) + pixel, glass.y);
	vec3 color = mix(empty, red, wet);
	color = mix(color, vec3(0.75, 0.27, 0.15), max(old_wet - wet, 0.0) * flash * 0.65);
	color = mix(color, vec3(0.63, 0.85, 0.56), max(wet - old_wet, 0.0) * flash * 0.78);
	float gold_line = 1.0 - smoothstep(pixel * 0.55, pixel * 1.75, abs(glass.y - gold_line_y));
	color = mix(color, vec3(0.84, 0.65, 0.35), gold_line * step(capacity, 0.999) * 0.85);

	// Curved highlights remain visible above the liquid surface.
	float light_arc = exp(-pow((r - 0.692) * 39.0, 2.0)) * smoothstep(0.27, 0.92, dot(normalize(p + vec2(0.0001)), vec2(-0.58, -0.81)));
	float glare = exp(-pow((p.x + 0.29 + p.y * 0.33) * 10.0, 2.0) - pow((p.y + 0.49) * 7.0, 2.0));
	color += vec3(0.34, 0.18, 0.16) * light_arc + vec3(0.19, 0.11, 0.10) * glare;
	color *= 1.0 - smoothstep(0.55, 0.81, r) * 0.55;

	float angle = atan(p.y, p.x);
	float weave = sin(angle * 9.0 + 0.8) * 0.014 + sin(angle * 17.0) * 0.010;
	float bark_r = r + weave;
	float u = 0.12 + 0.76 * (1.0 - abs(fract((angle + 3.14159265) / 3.14159265) * 2.0 - 1.0));
	vec4 roots = texture(bark, vec2(u, mix(0.082, 0.045, smoothstep(0.77, 0.96, bark_r))));
	float rim = smoothstep(0.755, 0.80, bark_r) * (1.0 - smoothstep(0.934, 0.977, bark_r));
	float glass_alpha = 1.0 - smoothstep(0.80 - pixel, 0.80 + pixel, r);
	float shadow = (1.0 - smoothstep(0.86, 0.99, length(p - vec2(0.0, 0.014)))) * 0.78;
	float alpha = max(max(glass_alpha, rim), shadow);
	vec3 base = mix(vec3(0.036, 0.021, 0.017), color, glass_alpha);
	vec3 wood = mix(vec3(0.14, 0.090, 0.050), roots.rgb, roots.a);
	wood *= mix(0.63, 1.35, clamp(-p.y * 0.52 + 0.58, 0.0, 1.0));
	COLOR = vec4(mix(base, wood, rim), alpha);
}
