shader_type canvas_item;

uniform float clock = 0.0;
uniform vec2 surface_size = vec2(64.0, 41.0);
uniform vec4 water_tint : source_color = vec4(0.90, 0.98, 1.0, 1.0);

// Sparse pixel-scale streaks accelerate toward a broken foam crest.
// Transparent upstream pixels preserve the lake's painted colour and shore.
void fragment() {
	vec2 p = floor(UV * surface_size);
	float lane = floor(p.x / 4.0);
	float seed = fract(sin(lane * 127.1 + 31.7) * 43758.5453);
	float pulse = fract(p.y / 18.0 - clock * (0.65 + seed * 0.35) + seed);
	float streak = step(0.80, pulse) * step(0.42, seed);
	float edge = smoothstep(0.0, 4.0, p.x) * (1.0 - smoothstep(surface_size.x - 4.0, surface_size.x, p.x));
	float downstream = smoothstep(0.0, 0.85, UV.y);
	float crest_y = surface_size.y - 5.0 + floor(sin(lane * 1.7 + clock * 3.0) * 1.5);
	float crest = step(crest_y, p.y) * (1.0 - step(crest_y + 2.0, p.y));
	float alpha = (streak * 0.30 * downstream + crest * 0.65) * edge;
	COLOR = vec4(vec3(0.66, 0.83, 0.87) * water_tint.rgb, alpha * water_tint.a);
}
