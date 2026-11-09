shader_type canvas_item;

// The final colour pass over the world (not the interface): cool shadows,
// warm lights, a touch more colour and a soft vignette. Stage 21.
uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float saturation = 1.1;
uniform float contrast = 1.05;
uniform vec3 shadow_tint = vec3(0.90, 0.93, 1.10);
uniform vec3 high_tint = vec3(1.06, 1.02, 0.93);
uniform float vignette = 0.32;
uniform float strength = 1.0;

void fragment() {
	vec3 source = texture(screen, SCREEN_UV).rgb;
	vec3 c = source;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	c *= mix(shadow_tint, high_tint, smoothstep(0.12, 0.72, l));
	vec2 p = SCREEN_UV - 0.5;
	c *= 1.0 - vignette * smoothstep(0.18, 0.75, dot(p, p) * 2.0);
	COLOR = vec4(mix(source, clamp(c, 0.0, 1.0), strength), 1.0);
}
