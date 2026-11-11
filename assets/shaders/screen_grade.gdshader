shader_type canvas_item;

// The final colour pass over the world (not the interface): cool shadows,
// warm lights and restrained foliage. One approved look, below the HUD.
// Nearest sampling preserves the source pixels at the game's viewport scale.
uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float saturation = 0.78;
uniform float contrast = 1.025;
uniform float gain = 0.94;
uniform vec3 shadow_tint = vec3(0.94, 0.97, 1.02);
uniform vec3 high_tint = vec3(1.015, 1.0, 0.96);
uniform float vignette = 0.12;
uniform float strength = 1.0;

void fragment() {
	vec3 source = texture(screen, SCREEN_UV).rgb;
	vec3 c = source;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	c *= mix(shadow_tint, high_tint, smoothstep(0.12, 0.72, l));
	// Roll off the brightest foliage/cloud highlights without crushing shade.
	c *= gain;
	c /= vec3(1.0) + max(c - vec3(0.68), vec3(0.0)) * 0.35;
	vec2 p = SCREEN_UV - 0.5;
	c *= 1.0 - vignette * smoothstep(0.18, 0.75, dot(p, p) * 2.0);
	COLOR = vec4(mix(source, clamp(c, 0.0, 1.0), strength), 1.0);
}
