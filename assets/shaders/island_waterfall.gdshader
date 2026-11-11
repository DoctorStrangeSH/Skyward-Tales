shader_type canvas_item;

uniform sampler2D atlas : source_color, filter_nearest;
uniform float clock = 0.0;
uniform float stream_width = 64.0;
uniform float drop_length = 240.0;
uniform vec4 water_tint : source_color = vec4(0.90, 0.98, 1.0, 1.0);
uniform float cloud_fade = 0.28;

// Cross-fade two cropped samples in both axes. Broad streams gain detail
// instead of magnifying one thin column; neither wrap produces a hard seam.
vec4 flow_sample(float frame, float x, float y) {
	vec2 cell = vec2(mod(frame, 6.0), floor(frame / 6.0));
	float phase = fract(x);
	vec2 a = vec2(mix(0.20, 0.78, phase), mix(0.12, 0.36, y));
	vec2 b = vec2(mix(0.20, 0.78, fract(phase + 0.5)), a.y);
	return mix(texture(atlas, (cell + a) / vec2(6.0, 4.0)),
		texture(atlas, (cell + b) / vec2(6.0, 4.0)), abs(phase * 2.0 - 1.0));
}

void fragment() {
	float frame = mod(floor(clock * 12.0), 24.0);
	float phase = fract(UV.y * drop_length / 36.0 - clock * 0.85);
	float x = UV.x * max(1.0, stream_width / 24.0);
	vec4 a = flow_sample(frame, x, phase);
	vec4 b = flow_sample(frame, x, fract(phase + 0.5));
	vec4 water = mix(a, b, abs(phase * 2.0 - 1.0));
	float l = dot(water.rgb, vec3(0.299, 0.587, 0.114));
	water.rgb = mix(vec3(l), water.rgb, 0.78) * water_tint.rgb;
	float lip = (1.0 - smoothstep(0.0, 0.025, UV.y)) * 0.30;
	water.rgb = mix(water.rgb, vec3(0.80, 0.88, 0.90), lip);
	float px = UV.x * stream_width;
	float edge = smoothstep(0.0, 1.0, px) * (1.0 - smoothstep(stream_width - 1.0, stream_width, px));
	float fade = cloud_fade > 0.0 ? 1.0 - smoothstep(1.0 - cloud_fade, 1.0, UV.y) : 1.0;
	COLOR = vec4(water.rgb, water.a * water_tint.a * edge * fade);
}
