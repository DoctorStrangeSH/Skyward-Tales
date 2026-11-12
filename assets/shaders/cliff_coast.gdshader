shader_type canvas_item;

// Move existing painted pixels with the coast; do not stretch their detail.
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

uniform float grass_lip = 14.0;
uniform float face_height = 200.0;
uniform float headroom = 0.0;
uniform vec2 outlets[16];
uniform int outlet_count = 0;
varying vec4 ink;

void vertex() {
	ink = COLOR;
	if (UV.y < 0.5) { VERTEX.y -= headroom; }
	world_at = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float coast = coast_y(world_at.x);
	float source_y = (world_at.y - coast + grass_lip) / face_height;
	if (source_y < 0.0 || source_y > 1.0) { discard; }
	for (int i = 0; i < 16; i++) {
		if (i >= outlet_count) { break; }
		if (abs(world_at.x - outlets[i].x) < outlets[i].y * 0.5 && world_at.y < coast + 8.0) { discard; }
	}
	COLOR = texture(TEXTURE, vec2(UV.x, source_y)) * ink;
}
