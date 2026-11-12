shader_type canvas_item;

uniform vec2 shore_points[32];
uniform int shore_count = 0;
uniform float rim_y = 1280.0;
varying vec2 world_at;

float coast_y(float x) {
	if (shore_count < 2) { return rim_y; }
	for (int i = 1; i < 32; i++) {
		if (i >= shore_count) { break; }
		vec2 a = shore_points[i - 1];
		vec2 b = shore_points[i];
		if (x <= b.x) {
			return mix(a.y, b.y, clamp((x - a.x) / (b.x - a.x), 0.0, 1.0));
		}
	}
	return shore_points[shore_count - 1].y;
}

void vertex() {
	world_at = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	if (world_at.y > coast_y(world_at.x)) { discard; }
}
