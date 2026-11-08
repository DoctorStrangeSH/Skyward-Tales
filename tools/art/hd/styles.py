"""Per-biome HD art: ground sources and colours, liquids, decals, trees,
bushes and the sky around the island. Sources are (pack file, crop box,
weight); "@2" is the pack's secondary master atlas."""

T = "skylands/terrain_tiles/sky_terrain_%03d.png"
N = "nature/%s.png"
C = "crystals/%s.png"
INNER = (16, 16, 112, 112)
A2 = "@2"

# Atlas tiles (secondary atlas): clean square samples.
SAND = (A2, (908, 780, 952, 828), 1.0)
SAND2 = (A2, (520, 330, 566, 374), 1.0)
SNOW = (A2, (908, 858, 952, 906), 1.0)
SNOW2 = (A2, (786, 330, 832, 374), 1.0)
MOSS = (A2, (712, 330, 758, 374), 1.0)
MOSS_STONE = (A2, (646, 330, 692, 374), 1.0)
STONE = (A2, (918, 330, 956, 374), 1.0)
DARK_STONE = (A2, (974, 330, 1022, 374), 1.0)
F_GRAY = (A2, (22, 872, 68, 926), 1.0)
F_BLUE = (A2, (88, 872, 134, 926), 1.0)
F_CRACK = (A2, (154, 872, 200, 926), 1.0)
F_MOSS = (A2, (306, 872, 360, 926), 1.0)
F_DARK = (A2, (22, 946, 68, 1000), 1.0)
F_RED = (A2, (88, 946, 134, 1000), 1.0)
F_BROWN = (A2, (154, 946, 200, 1000), 1.0)
LILY = (A2, (300, 408, 346, 452))

GRASS = [(T % 1, (44, 16, 112, 112), 3.0), (T % 2, INNER, 2.0), (T % 5, INNER, 0.35), (T % 12, INNER, 0.15), (T % 3, INNER, 0.15)]
PLAIN_GRASS = [(T % 1, (44, 16, 112, 112), 3.0), (T % 2, INNER, 2.0)]

FLOWERS = [(N % "nature_024", 15, 70), (N % "nature_025", 15, 60), (N % "nature_extra_023", 14, 55),
           (N % "nature_extra_024", 14, 55), (N % "nature_extra_027", 13, 50), (N % "nature_extra_029", 13, 40),
           (N % "nature_extra_034", 14, 40), (N % "nature_extra_035", 13, 40), (N % "nature_extra_038", 13, 35)]
STONES = [(N % "nature_022", 16, 10), (N % "nature_018", 18, 6), (N % "nature_017", 16, 5)]
MUSHROOMS = [(N % "nature_extra_025", 10, 12), (N % "nature_extra_037", 10, 10)]
GLOW_FLORA = [(C % "arcane_flora/arcane_flora_018", 14, 30), (C % "arcane_flora/arcane_flora_021", 14, 30),
              (C % "arcane_flora/arcane_flora_027", 12, 30), (C % "arcane_flora/arcane_flora_011", 14, 18),
              (C % "arcane_flora/arcane_flora_009", 16, 12), (C % "arcane_flora/arcane_flora_025", 12, 26)]
CRYSTAL_BITS = [(C % "crystal_ores/crystal_ore_008", 16, 26), (C % "crystal_ores/crystal_ore_009", 16, 22),
                (C % "crystal_ores/crystal_ore_007", 16, 22), (C % "crystal_ores/crystal_ore_013", 12, 18)]

DIRT = [(92, 58, 36), (128, 84, 50), (164, 112, 68), (190, 138, 88), (214, 170, 118)]
STONE_PAL = [(60, 56, 60), (96, 88, 90), (132, 122, 118), (170, 158, 146), (204, 192, 176)]

DAY = {
    "grass": GRASS,
    "shade": (0.66, 0.98),
    "dirt": DIRT,
    "dirt_tile": (T % 7, (36, 62, 96, 94)),
    "stone": STONE_PAL,
    "water": [(70, 168, 196), (26, 82, 140)],
    "decals": FLOWERS + STONES + MUSHROOMS,
    "trees": [(N % "summer_oak", 62), (N % "nature_extra_014", 62), (N % "fruit_tree", 58), (N % "summer_oak", 66)],
    "bushes": [(N % "nature_023", 22), (N % "nature_016", 24), (N % "nature_019", 22), (N % "nature_extra_032", 24)],
    "sky": "day",
}

HAVEN = dict(DAY)
HAVEN.update({
    "decals": FLOWERS + FLOWERS + STONES[:2],
    "trees": [(N % "spring_blossom_tree", 62), (N % "nature_extra_022", 62), (N % "summer_oak", 62), (N % "spring_blossom_tree", 66)],
    "bushes": [(N % "nature_extra_023", 20), (N % "nature_016", 24), (N % "nature_031", 22), (N % "nature_extra_032", 24)],
    "warm": (1.06, 1.0, 0.9),
})

# Enchanted moonlit forest: deep blue-green moss, glowing flora and pools.
NIGHT = dict(DAY)
NIGHT.update({
    "grass": GRASS[:2],
    "recolor": (0.38, 0.62, 0.78),
    "overlays": [{"sources": [MOSS], "recolor": (0.42, 0.6, 0.72), "cell": 120, "cover": 0.35}],
    "shade": (0.7, 1.0),
    "warm": (0.96, 1.0, 1.06), "cool": (0.86, 0.92, 1.1),
    "dirt": [(34, 40, 58), (50, 60, 82), (66, 80, 104), (86, 100, 126), (110, 126, 150)],
    "dirt_tile": None,
    "stone": [(36, 40, 60), (58, 64, 88), (84, 92, 120), (112, 122, 150), (150, 160, 188)],
    "water": [(60, 200, 220), (20, 70, 130)],
    "liquid": "glow",
    "decals": GLOW_FLORA + [(N % "nature_022", 16, 8)],
    "decal_tint": (0.9, 0.95, 1.05),
    "trees": [(N % "blue_magic_tree", 62), (N % "crystal_tree", 60), (N % "purple_magic_tree", 64), (N % "nature_extra_019", 62)],
    "bushes": [(C % "arcane_flora/arcane_flora_011", 20), (C % "arcane_flora/arcane_flora_018", 20), (C % "arcane_flora/arcane_flora_006", 22), (N % "nature_036", 22)],
    "sky": "night",
    "shadow": 0.5,
})

# Misty marsh: olive moss and mud, murky bog water with lily pads.
MARSH = dict(DAY)
MARSH.update({
    "grass": PLAIN_GRASS,
    "recolor": (0.6, 0.7, 0.42),
    "overlays": [{"sources": [MOSS, (A2, (590, 330, 630, 374), 1.0)], "recolor": (0.62, 0.66, 0.46), "cell": 110, "cover": 0.45}],
    "shade": (0.62, 0.92),
    "dirt": [(52, 44, 30), (72, 62, 40), (94, 82, 54), (114, 100, 66), (136, 122, 84)],
    "dirt_tile": None,
    "water": [(70, 96, 66), (30, 46, 38)],
    "liquid": "murk",
    "water_decals": [(LILY[0], LILY[1], 18, 70)],
    "decals": [(N % "nature_027", 16, 40), (N % "nature_037", 14, 40), (N % "nature_030", 16, 30)] + MUSHROOMS + [(N % "nature_022", 16, 10)],
    "trees": [(N % "weeping_willow", 62), (N % "dead_tree", 58), (N % "weeping_willow", 66), (N % "nature_extra_020", 44)],
    "bushes": [(N % "nature_027", 22), (N % "nature_030", 22), (N % "nature_037", 20), (N % "nature_019", 22)],
    "sky": "dusk",
})

# Salt coast: warm sand, turquoise sea, palms.
COAST = dict(DAY)
COAST.update({
    "grass": [SAND, SAND2],
    "patch": 40, "step": 26,
    "overlays": [{"sources": PLAIN_GRASS, "recolor": (0.9, 0.95, 0.75), "cell": 160, "cover": 0.22}],
    "shade": (0.86, 1.04),
    "warm": (1.03, 1.0, 0.94), "cool": (0.96, 0.98, 1.0),
    "dirt": [(150, 118, 80), (176, 142, 100), (196, 164, 120), (214, 186, 144), (230, 206, 168)],
    "dirt_tile": None,
    "water": [(86, 206, 214), (24, 104, 168)],
    "decals": [(N % "nature_extra_031", 8, 30), (N % "nature_022", 14, 10), (N % "nature_027", 14, 18)],
    "lip": [SAND, SAND2], "vines": False,
    "trees": [(N % "palm_tree", 58), ("buildings/palm_tree_small.png", 52), ("buildings/buildings_extra_010.png", 56), (N % "palm_tree", 62)],
    "bushes": [(N % "nature_027", 20), (N % "nature_030", 20), (N % "nature_023", 20), (N % "nature_extra_032", 20)],
    "sky": "day",
})

# Stone pass: cold grass, bare rock and snowfields, snowy pines.
MOUNTAIN = dict(DAY)
MOUNTAIN.update({
    "grass": PLAIN_GRASS,
    "recolor": (0.74, 0.86, 0.8),
    "overlays": [{"sources": [STONE, MOSS_STONE], "cell": 120, "cover": 0.35},
                 {"sources": [SNOW, SNOW2], "cell": 150, "cover": 0.32}],
    "shade": (0.78, 1.04),
    "warm": (1.0, 1.0, 1.0), "cool": (0.9, 0.96, 1.06),
    "dirt": [(80, 72, 70), (106, 96, 92), (132, 122, 116), (158, 148, 140), (184, 176, 168)],
    "dirt_tile": None,
    "water": [(110, 180, 210), (40, 90, 140)],
    "decals": STONES + STONES + [(N % "nature_extra_012", 14, 20), (N % "nature_extra_013", 12, 16)],
    "trees": [(N % "pine_tree", 46), (N % "pine_tree", 52), (N % "snow_blossom_tree", 58), (N % "nature_extra_020", 44)],
    "bushes": [(N % "nature_extra_009", 22), (N % "nature_extra_010", 22), (N % "nature_018", 22), (N % "nature_extra_012", 20)],
    "sky": "cold",
})

# Floating sky islands: bright meadows, white and pink blossom.
SKY = dict(DAY)
SKY.update({
    "trees": [(N % "summer_oak", 60), (N % "snow_blossom_tree", 60), (N % "spring_blossom_tree", 60), (N % "nature_extra_018", 62)],
    "decals": FLOWERS + STONES[:1],
})

# Wind spires: golden autumn grass under a sunset sky.
SPIRES = dict(DAY)
SPIRES.update({
    "recolor": (1.08, 0.92, 0.55),
    "shade": (0.72, 1.0),
    "trees": [(N % "golden_tree", 60), (N % "autumn_tree_orange", 60), (N % "nature_extra_016", 60), (N % "nature_extra_015", 62)],
    "bushes": [(N % "nature_019", 22), (N % "nature_extra_032", 22), (N % "nature_016", 22), (N % "nature_036", 20)],
    "decals": [(N % "nature_extra_029", 13, 40), (N % "nature_024", 14, 40)] + STONES,
    "decal_tint": (1.0, 0.95, 0.85),
    "sky": "sunset",
})

# Shattered rift: violet corrupted ground, thorny arcane growth.
RIFT = dict(DAY)
RIFT.update({
    "grass": [DARK_STONE, F_CRACK, F_DARK],
    "patch": 40, "step": 26,
    "recolor": (0.78, 0.6, 1.0),
    "overlays": [{"sources": [MOSS], "recolor": (0.5, 0.38, 0.7), "cell": 110, "cover": 0.3}],
    "lip": [DARK_STONE, F_CRACK], "lip_tint": (0.78, 0.6, 1.0), "vines": False,
    "shade": (0.62, 0.95),
    "warm": (1.02, 0.96, 1.08), "cool": (0.86, 0.84, 1.08),
    "dirt": [(46, 34, 64), (66, 50, 90), (88, 70, 116), (112, 92, 142), (138, 118, 168)],
    "dirt_tile": None,
    "stone": [(40, 30, 56), (64, 52, 86), (92, 78, 118), (122, 108, 150), (156, 142, 182)],
    "water": [(170, 110, 230), (60, 30, 110)],
    "liquid": "glow",
    "decals": [(C % "arcane_flora/arcane_flora_013", 16, 30), (C % "arcane_flora/arcane_flora_012", 12, 26), (C % "crystal_ores/crystal_ore_007", 14, 20)],
    "trees": [(N % "purple_magic_tree", 62), (N % "dead_tree", 58), (N % "crystal_tree", 58), (C % "arcane_flora/arcane_flora_003", 46)],
    "bushes": [(C % "arcane_flora/arcane_flora_004", 22), (C % "arcane_flora/arcane_flora_007", 22), (C % "arcane_flora/arcane_flora_010", 20), (C % "arcane_flora/arcane_flora_001", 22)],
    "sky": "violet",
    "shadow": 0.5,
})

# Ashen waste: dark ash and scorched rock, lava pools, dead trees.
ASH = dict(DAY)
ASH.update({
    "grass": [F_DARK, F_BROWN, DARK_STONE],
    "patch": 40, "step": 26,
    "recolor": (0.86, 0.8, 0.76),
    "overlays": [{"sources": [F_RED, F_CRACK], "recolor": (0.9, 0.78, 0.72), "cell": 130, "cover": 0.35}],
    "shade": (0.7, 1.02),
    "warm": (1.06, 0.98, 0.92), "cool": (0.92, 0.92, 0.96),
    "dirt": [(40, 30, 28), (58, 44, 40), (78, 60, 52), (98, 78, 66), (120, 98, 84)],
    "dirt_tile": None,
    "stone": [(36, 30, 30), (58, 50, 48), (84, 74, 70), (112, 100, 94), (140, 128, 120)],
    "water": [(255, 160, 40), (180, 40, 10)],
    "liquid": "lava",
    "lip": [F_DARK, F_BROWN], "vines": False, "falls": 2, "fall_color": (1.0, 0.55, 0.15),
    "decals": [(N % "nature_018", 16, 10), (N % "nature_extra_040", 16, 14), (C % "crystal_ores/crystal_ore_022", 14, 8)],
    "decal_tint": (0.7, 0.62, 0.6),
    "trees": [(N % "dead_tree", 58), (N % "dead_tree", 64), (N % "dead_tree", 52)],
    "bushes": [(N % "nature_017", 22), (N % "nature_018", 22), (N % "nature_extra_043", 22), (N % "nature_extra_044", 22)],
    "sky": "ash",
    "shadow": 0.5,
})

# Crystal caves: blue stone floor, glowing pools, crystal clusters; rock rim.
CAVE = dict(DAY)
CAVE.update({
    "grass": [F_BLUE, F_GRAY, F_CRACK],
    "patch": 40, "step": 26,
    "recolor": (0.72, 0.74, 0.92),
    "overlays": [{"sources": [F_MOSS], "recolor": (0.5, 0.6, 0.8), "cell": 110, "cover": 0.25}],
    "shade": (0.6, 0.95),
    "warm": (1.0, 1.0, 1.06), "cool": (0.86, 0.88, 1.08),
    "dirt": [(40, 38, 58), (56, 54, 80), (74, 72, 104), (96, 94, 128), (120, 118, 152)],
    "dirt_tile": None,
    "stone": [(36, 34, 52), (58, 56, 82), (86, 84, 114), (114, 112, 146), (150, 148, 182)],
    "water": [(90, 200, 240), (24, 60, 130)],
    "liquid": "glow",
    "cave_rim": True,
    "walls": [F_DARK, DARK_STONE],
    "walkways": False,
    "decals": CRYSTAL_BITS + [(N % "nature_extra_031", 8, 30)],
    "trees": [(C % "crystal_ores/crystal_ore_001", 44), (C % "crystal_ores/crystal_ore_005", 44), (C % "crystal_ores/crystal_ore_002", 44), ("anomalies/anomalies_extra_014.png", 48)],
    "bushes": [(C % "crystal_ores/crystal_ore_026", 24), (C % "crystal_ores/crystal_ore_027", 24), (C % "crystal_ores/crystal_ore_024", 24), (C % "crystal_ores/crystal_ore_025", 24)],
    "apron": False,
    "shadow": 0.5,
})

# Dungeons: flagstone rooms inside brick walls.
CRYPT = dict(CAVE)
CRYPT.update({
    "grass": [F_GRAY, F_CRACK, F_DARK],
    "recolor": (0.92, 0.88, 0.84),
    "overlays": [{"sources": [F_MOSS], "recolor": (0.7, 0.75, 0.6), "cell": 90, "cover": 0.2}],
    "warm": (1.04, 1.0, 0.94), "cool": (0.94, 0.94, 1.0),
    "crypt": True,
    "cave_rim": False,
    "walls": [F_DARK, DARK_STONE],
    "decals": [(N % "nature_extra_031", 8, 40), ("dungeons/ruins_statues/ruins_statues_003.png", 10, 14)],
    "trees": [("dungeons/ruins_statues/ruins_statues_009.png", 30), ("dungeons/ruins_statues/ruins_statues_011.png", 30), ("dungeons/ruins_statues/ruins_statues_008.png", 34)],
    "bushes": [("dungeons/ruins_statues/ruins_statues_002.png", 20), ("dungeons/ruins_statues/ruins_statues_001.png", 22)],
})

MAGMA = dict(CRYPT)
MAGMA.update({
    "grass": [F_RED, F_BROWN, F_DARK],
    "recolor": (1.0, 0.86, 0.8),
    "overlays": [],
    "water": [(255, 160, 40), (180, 40, 10)],
    "liquid": "lava",
    "trees": [(C % "crystal_ores/crystal_ore_022", 34), ("anomalies/anomalies_extra_015.png", 40), (C % "crystal_ores/crystal_ore_023", 34)],
    "bushes": [(N % "nature_018", 22), (C % "crystal_ores/crystal_ore_022", 22)],
})

STYLE = {"day": DAY, "haven": HAVEN, "night": NIGHT, "marsh": MARSH, "coast": COAST, "mountain": MOUNTAIN,
         "sky": SKY, "spires": SPIRES, "rift": RIFT, "ash": ASH, "cave": CAVE, "crypt": CRYPT, "magma": MAGMA}
