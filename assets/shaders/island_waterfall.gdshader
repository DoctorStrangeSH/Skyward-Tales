shader_type canvas_item;

// Animate the broad middle of the existing atlas, not its icicle-shaped tail.
// Both flow samples cross-fade at wrap points, so no horizontal cut travels
// through the stream. Clock is supplied by the node and pauses with the game.
uniform sampler2D atlas : source_color, filter_nearest;
uniform float clock = 0.0;
uniform float drop_length = 180.0;

vec4 flow_sample(float frame, float x, float y) {
	vec2 cell = vec2(mod(frame, 6.0), floor(frame / 6.0));
	vec2 at = vec2(mix(0.17, 0.80, x), mix(0.12, 0.36, y));
	return texture(atlas, (cell + at) / vec2(6.0, 4.0));
}

void fragment() {
	float frame = mod(floor(clock * 12.0), 24.0);
	float phase = fract(UV.y * drop_length / 36.0 - clock * 0.85);
	vec4 a = flow_sample(frame, UV.x, phase);
	vec4 b = flow_sample(frame, UV.x, fract(phase + 0.5));
	vec4 water = mix(a, b, abs(phase * 2.0 - 1.0));
	float l = dot(water.rgb, vec3(0.299, 0.587, 0.114));
	water.rgb = mix(vec3(l), water.rgb, 0.72) * vec3(0.78, 0.88, 0.96);
	// A small foamy lip at the actual mouth, never a detached splash at midair.
	float lip = (1.0 - smoothstep(0.0, 0.025, UV.y)) * 0.35;
	water.rgb = mix(water.rgb, vec3(0.76, 0.85, 0.88), lip);
	float edge = smoothstep(0.0, 0.055, UV.x) * (1.0 - smoothstep(0.945, 1.0, UV.x));
	float fade = 1.0 - smoothstep(0.72, 1.0, UV.y);
	COLOR = vec4(water.rgb, water.a * edge * fade);
}
