"""Colour ramps. Warm sunlit greens by day, cool teal/violet moonlight by night.
Shadows lean blue/purple instead of black, outlines are tinted, never pure black."""
from pixel import hex_color, ramp

DAY = {
    "grass": ramp("#183b35", "#22533c", "#2e6b40", "#468a45", "#6aa84c", "#9ccb5a", "#cfe77a"),
    "dirt": ramp("#3f2a2c", "#5e3d33", "#81573d", "#a77649", "#c99a5d", "#e3c286"),
    "water": ramp("#0e2a46", "#14496a", "#1b6f8a", "#2f9aa6", "#6fd0c6", "#d6f6ea"),
    "stone": ramp("#262536", "#3c3d52", "#5a6074", "#7f899a", "#a9b3bd", "#d6dcdc"),
    "leaf": ramp("#14302f", "#1c4a3a", "#286541", "#3d8446", "#5ea64e", "#8fc95a", "#c6e777"),
    "bark": ramp("#2a1b22", "#43292a", "#633d32", "#86573f", "#a9744d"),
    "moss": ramp("#2c4a2e", "#3f6b33", "#5f8f3c", "#8ab54a"),
    "shadow": hex_color("#10202a", 96),
    "outline": hex_color("#151c26"),
    "flowers": [ramp("#f4f1de", "#c9c3b0"), ramp("#f6d55c", "#c99a2e"), ramp("#f28fb1", "#b45a80"), ramp("#93bcff", "#5a78c8")],
}

NIGHT = {
    "grass": ramp("#0b1a26", "#10283a", "#163a4a", "#1f5056", "#2d6a64", "#468a78", "#74b292"),
    "dirt": ramp("#1e1a2a", "#2c2638", "#3d3448", "#52475a", "#6c5f70", "#8c7f8c"),
    "water": ramp("#08162e", "#0f2c52", "#164b7c", "#2878ad", "#5fb6e0", "#c6f0ff"),
    "stone": ramp("#161827", "#24283b", "#373e54", "#4f5a70", "#6f7e92", "#9fb0bd"),
    "leaf": ramp("#0a1724", "#0f2635", "#163a46", "#1f5054", "#2e6a63", "#468a78", "#7bc3a4"),
    "bark": ramp("#15111c", "#231b29", "#342834", "#4a3a44", "#625058"),
    "moss": ramp("#173238", "#204a48", "#2f6a5a", "#4a9278"),
    "shadow": hex_color("#050a14", 110),
    "outline": hex_color("#070b16"),
    "glow": ramp("#3fd6d0", "#8ff7ef", "#e2fffb"),
    "flowers": [ramp("#8ff7ef", "#3aa9b0"), ramp("#c9a2ff", "#7b5bc4"), ramp("#e6f4ff", "#8aa2c0")],
}

CAVE = {
    # "grass" is the cave floor, "dirt" the worn path, "leaf" the rock walls.
    "grass": ramp("#0e0c18", "#17142a", "#201c38", "#2a2546", "#363056", "#463f6a", "#5c5486"),
    "dirt": ramp("#1a1624", "#2a2434", "#3a3346", "#4c4458", "#625a70", "#807a90"),
    "water": ramp("#0a1030", "#141e5a", "#22348a", "#3a5cc0", "#7aa6f0", "#d6e8ff"),
    "stone": ramp("#14121f", "#221f33", "#34304a", "#4a4664", "#67638a", "#9690b8"),
    "leaf": ramp("#0a0912", "#14121f", "#211d33", "#2e2a46", "#3e395c", "#524c74", "#6a6494"),
    "bark": ramp("#14121f", "#221f33", "#34304a", "#4a4664", "#67638a"),
    "moss": ramp("#1d3a4a", "#245a62", "#2f7a78", "#4aa69a"),
    "shadow": hex_color("#05040c", 120),
    "outline": hex_color("#06050c"),
    "glow": ramp("#9a7aff", "#d0b8ff", "#f6f0ff"),
    "crystal": ramp("#f6f0ff", "#d0b8ff", "#9a7aff", "#6a4ad8", "#3a2a8a"),
    "flowers": [ramp("#d0b8ff", "#7a5ad8"), ramp("#8fe0ff", "#3a8ac8"), ramp("#f6f0ff", "#9a90c0")],
}

SKY = {
    # Bright, airy: pale marble paths, soft spring grass, blossom trees.
    "grass": ramp("#2a5a5a", "#3a7a6a", "#4f9a72", "#6db87e", "#92d08e", "#bfe6a6", "#e6f6c6"),
    "dirt": ramp("#6a6a8a", "#8a8ca8", "#a8adc4", "#c6cadc", "#e0e3ee", "#f6f7fb"),
    "water": ramp("#2a4a8a", "#3a6ab0", "#5a92d0", "#86baea", "#b8dcf8", "#f0f8ff"),
    "stone": ramp("#4a4a66", "#6a6c8a", "#9094b0", "#b8bdd2", "#dcdfea", "#f8f8fc"),
    "leaf": ramp("#5a2a4a", "#8a3a6a", "#b85a8a", "#de86ac", "#f4aac6", "#ffd0e0", "#fff0f6"),
    "bark": ramp("#3a2a3a", "#5a3e4a", "#7a5a62", "#9a7a7e", "#b89a98"),
    "moss": ramp("#3a7a6a", "#4f9a72", "#6db87e", "#92d08e"),
    "shadow": hex_color("#1a2a4a", 80),
    "outline": hex_color("#2a2440"),
    "sky": ramp("#6a9ae0", "#86b2ec", "#a6caf4", "#c8e0fa"),
    "cloud": ramp("#8aa6d0", "#a8c0e4", "#c6d8f2", "#dce8f8", "#eef4fc", "#f8fbff", "#ffffff"),
    "flowers": [ramp("#ffffff", "#d8e0f0"), ramp("#ffd6e8", "#e08aac"), ramp("#fff2a8", "#e0b84a")],
}

STYLES = {"day": DAY, "night": NIGHT, "cave": CAVE, "sky": SKY}
