shader_type canvas_item;

// 0 = normal, 1 = fully white silhouette. Animated by Vfx.flash().
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV) * COLOR;
	tex.rgb = mix(tex.rgb, flash_color.rgb, flash);
	COLOR = tex;
}
