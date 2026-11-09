/* Renders a list of MIDI-like events through a SoundFont (TinySoundFont,
 * MIT, fetched by tools/audio/orchestra.py) into raw stereo float32.
 *
 *   sf_render <bank.sf2> <events.txt> <out.f32> <seconds> [rate]
 *
 * events.txt — one event per line, any order (sorted here):
 *   <time_s> P <ch> <bank> <preset>      choose an instrument
 *   <time_s> N <ch> <key> <vel 1..127>   note on
 *   <time_s> F <ch> <key>                note off
 *   <time_s> C <ch> <cc> <value>         controller (7 volume, 10 pan, 11 expression, 64 sustain)
 *   <time_s> W <ch> <0..16383>           pitch wheel (8192 = centre)
 */
#define TSF_IMPLEMENTATION
#include "tsf.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct { double t; char kind; int ch, a, b, c; int order; } Ev;

static int cmp(const void* x, const void* y) {
	const Ev* p = (const Ev*)x; const Ev* q = (const Ev*)y;
	if (p->t < q->t) return -1;
	if (p->t > q->t) return 1;
	/* program changes first, then note offs, then the rest */
	int rp = p->kind == 'P' ? 0 : (p->kind == 'F' ? 1 : 2);
	int rq = q->kind == 'P' ? 0 : (q->kind == 'F' ? 1 : 2);
	if (rp != rq) return rp - rq;
	return p->order - q->order;
}

int main(int argc, char** argv) {
	if (argc < 5) { fprintf(stderr, "usage\n"); return 2; }
	int rate = argc > 5 ? atoi(argv[5]) : 44100;
	tsf* f = tsf_load_filename(argv[1]);
	if (!f) { fprintf(stderr, "cannot load %s\n", argv[1]); return 1; }
	tsf_set_output(f, TSF_STEREO_INTERLEAVED, rate, -6.0f);
	tsf_set_max_voices(f, 256);
	FILE* in = fopen(argv[2], "r");
	if (!in) return 1;
	int cap = 1024, n = 0;
	Ev* ev = malloc(sizeof(Ev) * cap);
	char line[256];
	while (fgets(line, sizeof line, in)) {
		Ev e; memset(&e, 0, sizeof e);
		if (sscanf(line, "%lf %c %d %d %d %d", &e.t, &e.kind, &e.ch, &e.a, &e.b, &e.c) < 3) continue;
		e.order = n;
		if (n == cap) { cap *= 2; ev = realloc(ev, sizeof(Ev) * cap); }
		ev[n++] = e;
	}
	fclose(in);
	qsort(ev, n, sizeof(Ev), cmp);
	long total = (long)(atof(argv[4]) * rate);
	float* buf = calloc((size_t)total * 2, sizeof(float));
	long pos = 0;
	for (int i = 0; i <= n; i++) {
		long until = i < n ? (long)(ev[i].t * rate) : total;
		if (until > total) until = total;
		if (until > pos) { tsf_render_float(f, buf + pos * 2, (int)(until - pos), 0); pos = until; }
		if (i == n) break;
		Ev* e = &ev[i];
		switch (e->kind) {
		case 'P': tsf_channel_set_bank_preset(f, e->ch, e->a, e->b); break;
		case 'N': tsf_channel_note_on(f, e->ch, e->a, e->b / 127.0f); break;
		case 'F': tsf_channel_note_off(f, e->ch, e->a); break;
		case 'C': tsf_channel_midi_control(f, e->ch, e->a, e->b); break;
		case 'W': tsf_channel_set_pitchwheel(f, e->ch, e->a); break;
		}
	}
	FILE* out = fopen(argv[3], "wb");
	fwrite(buf, sizeof(float), (size_t)total * 2, out);
	fclose(out);
	return 0;
}
