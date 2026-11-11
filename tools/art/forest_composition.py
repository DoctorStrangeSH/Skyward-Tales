"""Authored groves with soft edges; deterministic spacing and playable clearings."""
from __future__ import annotations
import math
import random

# centre, radii, species, density. Routes and landmarks take precedence.
GROVES = [
    (165, 300, 130, 205, 0, .85), (560, 205, 240, 170, 1, .85),
    (1050, 180, 275, 160, 0, .95), (1510, 135, 200, 100, 1, .8),
    (1790, 370, 105, 190, 0, .8), (1080, 415, 150, 160, 1, .75),
    (1390, 720, 205, 135, 0, .9), (1800, 800, 90, 150, 1, .8),
    (130, 965, 90, 220, 0, .85), (530, 1165, 235, 80, 1, .8),
    (1040, 1115, 235, 100, 0, .8), (1280, 940, 100, 135, 1, .7),
    (1810, 1165, 70, 75, 0, .7),
    (275, 495, 65, 85, 0, .75), (880, 865, 115, 120, 0, .65),
    (430, 1045, 145, 80, 1, .7), (815, 1020, 100, 100, 0, .65),
]

def segment_distance(p, a, b):
    vx, vy = b[0] - a[0], b[1] - a[1]
    t = max(0, min(1, ((p[0]-a[0])*vx + (p[1]-a[1])*vy) / max(1, vx*vx+vy*vy)))
    return math.hypot(p[0]-a[0]-t*vx, p[1]-a[1]-t*vy)

def compose(region, force=False):
    terrain = region['terrain']
    terrain['bridge_landings'] = False
    if terrain.get("forest_composition") == "authored_groves_v2" and not force:
        return len(terrain["trees"])
    width, height = terrain['size']
    rng = random.Random(110126)
    landmarks = []
    for key in ('npcs', 'chests', 'gather', 'resource_nodes', 'story_objects', 'gates'):
        landmarks.extend((x['position'], 56 if key == 'gather' else 68) for x in region.get(key, []))
    landmarks.extend((p, 60) for key in ('supply_crates', 'map_fragments') for p in region.get(key, []))
    landmarks.extend([([1620, 510], 120), ([1120, 870], 100), (region['waystone'], 65)])
    def clear(x, y):
        # Canopy occupies the area above the root. Protect the entire silhouette.
        if not (48 < x < width-48 and 100 < y < height-40):
            return False
        if any(segment_distance((x, y-20), a, b) < 62 for trail in terrain['trails'] for a,b in zip(trail,trail[1:])):
            return False
        if any(math.hypot(x-p[0], (y-22-p[1])*1.15) < r for p,r in landmarks):
            return False
        for block in terrain['blockers']:
            bx,by = block['center']; bw,bh = block['size']
            if abs(x-bx)<bw/2+48 and abs(y-30-by)<bh/2+65:
                return False
        for pond in terrain['ponds']:
            if 'circle' in pond:
                cx,cy,r = pond['circle']
                if math.hypot(x-cx, y-25-cy) < r+62:
                    return False
            else:
                px,py,pw,ph = pond['rect']
                if px-55 < x < px+pw+55 and py-50 < y < py+ph+95:
                    return False
        return True
    candidates = []
    for _ in range(14000):
        x,y = rng.uniform(45,width-45),rng.uniform(100,height-40)
        scores = [(max(0,1-((x-cx)/rx)**2-((y-cy)/ry)**2)*density, species) for cx,cy,rx,ry,species,density in GROVES]
        score,species = max(scores)
        if rng.random() < score and clear(x,y):
            candidates.append((score+rng.random()*.22,round(x),round(y),species))
    chosen = []
    for _,x,y,species in sorted(candidates,reverse=True):
        if all(((x-a)/64)**2+((y-b)/56)**2 > 1 for a,b,_ in chosen):
            chosen.append((x,y,species*2+rng.randrange(2)))
    chosen.sort(key=lambda p:(p[1],p[0]))
    terrain['trees'] = [[x,y] for x,y,_ in chosen]
    terrain['tree_variants'] = [v for _,_,v in chosen]
    terrain['forest_composition'] = 'authored_groves_v2'
    return len(chosen)
