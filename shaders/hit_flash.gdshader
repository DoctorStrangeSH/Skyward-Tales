shader_type canvas_item;

// 0 = normal, 1 = fully white silhouette. Animated by Vfx.flash().
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// Recolours a creature (turns of the colour wheel, 0 = as drawn) — e.g.
// Lira's pink living potions from the green slime (stage 20).
uniform float hue_shift = 0.0;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (hue_shift != 0.0) {
		vec3 hsv = rgb2hsv(tex.rgb);
		hsv.x = fract(hsv.x + hue_shift);
		tex.rgb = hsv2rgb(hsv);
	}
	tex *= COLOR;
	tex.rgb = mix(tex.rgb, flash_color.rgb, flash);
	COLOR = tex;
}
