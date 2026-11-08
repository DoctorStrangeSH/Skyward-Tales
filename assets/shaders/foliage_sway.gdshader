shader_type canvas_item;

// Trees and bushes sway in the wind (tech debt from Этап 6). The bottom of
// the sprite stays put, the crown moves; the phase comes from the sprite's
// world position so neighbours do not move in lockstep.
uniform float strength = 4.0;
uniform float speed = 1.0;
// The world's own clock (scripts/world.gd), not TIME: it stops when the game
// is paused, so the trees freeze with everything else (owner's list №6).
uniform float clock = 0.0;

void vertex() {
	float phase = MODEL_MATRIX[3].x * 0.031 + MODEL_MATRIX[3].y * 0.017;
	float top = 1.0 - UV.y;
	float wave = sin(clock * 1.3 * speed + phase) * 0.6 + sin(clock * 2.1 * speed + phase * 1.7) * 0.4;
	VERTEX.x += wave * strength * top * top;
}
