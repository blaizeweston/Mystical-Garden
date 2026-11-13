"""Render the class skill atlas. Run from the project folder with Pillow installed."""
from pathlib import Path
import json
import random
from PIL import Image, ImageDraw

# Each cell has a separate silhouette, with shared class colors and stone edging.
ICONS = [
  [
    "Guard",
    0,
    "P 18 17 32 12 46 17 44 38 32 49 20 38|L 32 20 32 39"
  ],
  [
    "Root Quake",
    0,
    "L 9 32 23 31 28 22 33 41 39 31 55 32|L 21 42 13 49|L 43 42 51 49|L 32 48 32 54"
  ],
  [
    "Living Bastion",
    0,
    "P 16 24 20 15 27 24 32 15 37 24 44 15 48 24 46 42 32 50 18 42|L 25 32 39 32|L 32 32 32 43"
  ],
  [
    "Briar Charge",
    0,
    "P 14 33 39 16 49 19 44 38|L 18 37 10 44|L 30 37 20 51|L 38 39 32 48"
  ],
  [
    "Rootshield",
    0,
    "P 14 19 32 13 50 19 46 39 32 51 18 39|L 32 21 32 42 25 46|L 32 28 23 23|L 32 34 41 29"
  ],
  [
    "Thorn Counter",
    0,
    "A 12 14 51 51 22 305|L 39 17 49 22 50 10|P 23 39 32 22 37 31 30 41"
  ],
  [
    "Sanctuary Quake",
    0,
    "A 12 13 52 53 185 355|L 14 37 24 37 28 29 34 47 40 36 51 36|L 32 16 32 28|L 26 22 38 22"
  ],
  [
    "Shattering Advance",
    0,
    "P 13 25 31 14 52 26 34 41|L 13 42 23 44 17 51|L 33 42 42 46 35 53"
  ],
  [
    "Root Anchor",
    0,
    "E 28 12 36 20|L 32 20 32 50|L 21 27 43 27|L 14 36 19 45 32 50 45 45 50 36|L 13 44 14 36 22 38|L 51 44 50 36 42 38"
  ],
  [
    "Rootbind",
    1,
    "L 16 15 20 28 30 31 30 47 22 53|L 48 13 41 28 34 33 34 46 43 52|P 26 23 32 19 39 24 32 33"
  ],
  [
    "Spore Nova",
    1,
    "E 25 25 39 39|L 32 13 32 21|L 32 43 32 52|L 13 32 21 32|L 43 32 51 32|L 17 17 23 23|L 41 41 47 47|L 41 23 47 17|L 17 47 23 41"
  ],
  [
    "Strangling Bloom",
    1,
    "A 15 17 48 46 190 360|L 17 30 18 43 31 50 47 44 49 30|P 26 31 32 21 39 31 32 40|L 21 41 44 41"
  ],
  [
    "Mycelial Snare",
    1,
    "P 32 13 50 24 48 42 32 52 16 42 14 24|L 14 24 32 32 50 24|L 16 42 32 32 48 42|L 32 13 32 52"
  ],
  [
    "Interwoven Bind",
    1,
    "L 16 13 18 23 42 39 48 51|L 49 13 43 23 21 39 16 51|L 24 23 40 23|L 24 42 40 42"
  ],
  [
    "Cultivate Bloom",
    1,
    "L 32 50 32 29|P 32 36 20 32 15 22 25 24|P 32 42 44 37 49 27 39 30|P 26 21 32 11 38 21 32 29|L 21 52 43 52"
  ],
  [
    "Entangling Chorus",
    1,
    "E 15 31 26 42|E 27 16 38 27|E 39 31 50 42|L 20 42 32 53 45 42|L 32 28 32 53"
  ],
  [
    "Bloom Detonation",
    1,
    "P 32 11 37 25 51 18 44 31 54 42 39 41 32 53 25 41 10 42 20 31 13 18 27 25|E 28 28 36 36"
  ],
  [
    "Silk Shelter",
    1,
    "A 11 14 53 54 180 360|L 12 35 23 46 42 46 52 35|L 32 16 20 45|L 32 16 44 45|L 15 32 49 32"
  ],
  [
    "Gale Volley",
    2,
    "L 16 43 44 15 34 16|L 44 15 43 26|L 27 49 52 25 43 26|L 52 25 51 34|L 12 31 28 15 20 16"
  ],
  [
    "Bramble Snare",
    2,
    "A 12 12 52 52 25 342|L 14 33 25 30 21 21|L 33 14 33 26 42 20|L 50 36 39 36 45 44|L 28 51 31 41 22 44"
  ],
  [
    "Piercing Salvo",
    2,
    "L 13 46 49 16 38 17|L 49 16 47 28|L 12 36 25 25|L 30 48 43 37|L 21 49 21 39 11 39"
  ],
  [
    "Windstep",
    2,
    "A 11 15 45 39 195 353|A 17 28 52 53 12 169|L 19 38 12 42 22 46|L 39 17 51 22 44 28"
  ],
  [
    "Hunter’s Salvo",
    2,
    "E 13 13 51 51|E 24 24 40 40|L 14 51 45 21 34 23|L 45 21 43 32"
  ],
  [
    "Luring Shot",
    2,
    "L 13 46 46 16 36 17|L 46 16 45 27|L 33 32 47 36 47 44|E 42 43 51 52"
  ],
  [
    "Stalker’s Retreat",
    2,
    "P 27 13 49 19 44 34 32 41 22 33|L 20 27 11 34 20 40|L 22 39 15 46 25 52"
  ],
  [
    "Thorn Lattice",
    2,
    "L 15 18 49 45|L 15 31 39 51|L 26 12 51 33|L 14 43 41 15|L 26 51 51 23|L 10 29 27 12"
  ],
  [
    "Luring Snare",
    2,
    "P 32 13 51 28 45 47 19 47 13 28|L 32 21 32 39|E 27 35 37 45|L 20 28 27 34|L 44 28 37 34"
  ],
  [
    "Briar Retreat",
    2,
    "L 13 30 33 13 26 28 50 28|L 33 32 19 43 44 43 51 52|L 36 44 41 37|L 24 43 19 51"
  ],
  [
    "Reaping Step",
    3,
    "A 14 10 52 42 195 357|L 35 20 29 36 17 49|L 41 35 53 42|L 9 45 15 40"
  ],
  [
    "Siphon Cut",
    3,
    "P 32 12 43 31 43 40 37 47 27 47 21 40 21 31|L 15 48 49 18"
  ],
  [
    "Shadow Harvest",
    3,
    "A 11 12 53 50 55 285|A 23 14 54 45 82 275|L 30 31 20 49|L 39 30 34 48"
  ],
  [
    "Blood Moon",
    3,
    "A 12 12 52 52 14 340|P 37 18 34 30 44 37 35 44 24 42 19 32 24 24|L 46 40 48 49"
  ],
  [
    "Harvest Frenzy",
    3,
    "L 12 44 25 24 39 14|L 22 48 37 25 50 17|L 33 51 44 34 53 29"
  ],
  [
    "Veil Passage",
    3,
    "A 15 10 49 52 175 365|L 15 31 15 50|L 49 31 49 50|L 21 43 34 31 43 32|L 35 24 43 32 37 39"
  ],
  [
    "Feast of Thorns",
    3,
    "P 11 25 20 17 26 28 32 17 38 28 44 17 53 25 46 42 32 49 18 42|L 19 37 45 37"
  ],
  [
    "Delayed Requiem",
    3,
    "L 19 15 45 15|L 19 49 45 49|P 22 17 42 17 40 26 32 32 40 39 42 47 22 47 24 39 32 32 24 26|E 30 41 34 45"
  ],
  [
    "Blood Harvest",
    3,
    "A 12 11 51 47 195 354|L 38 19 24 50|P 44 30 51 43 49 48 42 48 38 43"
  ],
  [
    "Grave Sweep",
    3,
    "A 10 13 54 51 150 349|P 22 35 22 22 32 15 42 22 42 35 37 35 37 43 27 43 27 35|E 25 26 30 31|E 34 26 39 31"
  ],
  [
    "Renewal",
    4,
    "P 27 13 37 13 37 26 50 26 50 36 37 36 37 49 27 49 27 36 14 36 14 26 27 26|L 19 46 23 42|L 45 17 41 21"
  ],
  [
    "Warding Chime",
    4,
    "P 18 39 23 33 24 21 32 15 40 21 41 33 46 39|L 29 45 35 45|A 10 18 54 54 16 162"
  ],
  [
    "Sanctuary",
    4,
    "A 10 12 54 56 180 360|L 10 34 10 49 54 49 54 34|L 32 23 32 43|L 22 33 42 33"
  ],
  [
    "Judgement Bell",
    4,
    "P 14 32 21 27 24 15 32 11 40 15 43 27 50 32|L 34 34 27 42 37 42 30 53"
  ],
  [
    "Living Sanctuary",
    4,
    "A 11 12 53 53 178 362|L 12 48 52 48|L 32 47 32 24|P 32 36 20 32 19 23 28 28|P 32 41 44 35 46 25 37 31"
  ],
  [
    "Foretell",
    4,
    "P 10 32 21 21 32 17 43 21 54 32 43 43 32 47 21 43|E 25 25 39 39|L 32 10 32 13|L 32 51 32 54"
  ],
  [
    "Cleansing Bower",
    4,
    "A 11 15 53 50 180 355|L 18 45 26 49 32 45 39 49 46 45|P 32 20 38 31 35 39 29 39 26 31"
  ],
  [
    "Sentence of Dawn",
    4,
    "P 32 12 36 24 47 18 42 29 54 33 42 37 47 48 36 42 32 54 28 42 17 48 22 37 10 33 22 29 17 18 28 24"
  ],
  [
    "Guiding Bell",
    4,
    "P 18 34 23 28 24 18 32 12 40 18 41 28 46 34|L 29 39 35 39|L 22 44 32 53 42 44|L 32 42 32 52"
  ]
]

CELL = 64
COLUMNS = 8
COLORS = ["#e7b584", "#cbb8ed", "#bbd89a", "#f1a8b2", "#f5dc91"]


def draw_icon(symbol, tint, seed):
    scale = 3
    layer = Image.new("RGBA", (CELL * scale, CELL * scale))
    draw = ImageDraw.Draw(layer)
    draw.rounded_rectangle((3*scale, 3*scale, 61*scale, 61*scale), 12*scale, fill="#141c18", outline="#425345", width=2*scale)
    draw.rounded_rectangle((6*scale, 6*scale, 58*scale, 58*scale), 9*scale, outline="#28362d", width=scale)
    rng = random.Random(seed)
    for _ in range(280):
        x, y = rng.uniform(9, 55), rng.uniform(9, 55)
        if (x-32)**2 + (y-32)**2 < 24**2:
            draw.point((int(x*scale), int(y*scale)), fill=rng.choice(["#233128", "#29332a", "#1a231d"]))
    for color, width in [("#0b110d", 5.4), (tint, 2.8)]:
        for command in symbol.split("|"):
            op, *numbers = command.split()
            values = list(map(int, numbers))
            if op in ("A", "E"):
                box = tuple(value*scale for value in values[:4])
                if op == "A":
                    draw.arc(box, values[4], values[5], fill=color, width=round(width*scale))
                else:
                    draw.ellipse(box, outline=color, width=round(width*scale))
                continue
            points = [(x*scale, y*scale) for x, y in zip(values[::2], values[1::2])]
            if op == "P":
                points.append(points[0])
            draw.line(points, fill=color, width=round(width*scale), joint="curve")
            radius = width*scale/2
            for x, y in (points[0], points[-1]):
                draw.ellipse((x-radius, y-radius, x+radius, y+radius), fill=color)
    return layer.resize((CELL, CELL), Image.Resampling.LANCZOS)


def main():
    folder = Path("assets/ui")
    atlas = Image.new("RGBA", (CELL*COLUMNS, CELL*((len(ICONS)+COLUMNS-1)//COLUMNS)))
    mapping = {}
    for i, (name, family, symbol) in enumerate(ICONS):
        x, y = CELL*(i%COLUMNS), CELL*(i//COLUMNS)
        atlas.paste(draw_icon(symbol, COLORS[family], i), (x, y))
        mapping[name] = [x, y, CELL, CELL]
    atlas.save(folder / "class_skills.png")
    (folder / "class_skill_icons.json").write_text(json.dumps(mapping, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")


if __name__ == "__main__":
    main()
