shader_type canvas_item;

// Cut only the grass lip at an authored outlet. Keep rock behind the fall.
uniform float outlet_x;
uniform float outlet_width;
uniform float rim_y;
varying vec2 world_at;

void vertex() {
	world_at = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	if (abs(world_at.x - outlet_x) < outlet_width * 0.5 && world_at.y < rim_y + 8.0) {
		discard;
	}
}
