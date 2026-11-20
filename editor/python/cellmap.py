#!/usr/bin/env python3
"""cellmap: the 1-bit to 3D editor's map data, outside LiveCode (LIB_BIT/editor).

A cellmap is a grid where every cell holds up to three things, each one character:
  design   a byte 0-255: which glyph of the map's 1-bit font builds this cell (its "wall design")
  tags     a letter: what the cell IS in the game (roguelike style: # wall, + door, ^ trap ...)
  heights  0-9 then A-Z (0-35): how far the cell is extruded; 9 = a full wall (wallH)
The file is plain UTF-8 text in [sections]; LiveCode reads it into a keyed array
(livecode/lib_cellmap.livecodescript) and this module reads it into a dict. Same data, both sides.

    python3 -I cellmap.py tags                 write data/tags_default.txt (256 tags, colours)
    python3 -I cellmap.py fonts                BitFontMaker2 .json in fonts/ -> .font.txt
    python3 -I cellmap.py example              write maps/amazing_couple.cellmap (Amazing Couple's defaults)
    python3 -I cellmap.py show FILE            print a cellmap: tags, design, heights
    python3 -I cellmap.py check FILE           read, write back, compare (round trip)
    python3 -I cellmap.py onebit FILE          the map as its 1-bit picture (half size, in the terminal)
    python3 -I cellmap.py sample               write maps/wizard_pool.cellmap (version 2: pool, dais, tower, clouds)
    python3 -I cellmap.py upgrade FILE OUT     a version 1 file as version 2
    python3 -I cellmap.py segments FILE        the level as line segments (CELLMAP_V2.md section 6)
    python3 -I cellmap.py heights FILE         floor / ceiling / red / green / blue as a table of rows
Version 2 (CELLMAP_V2.md): floor, ceiling, red, green, blue 0-255 a cell in height units (100 = a full
hallway), links, objects, stacked maps; levels(), stand_at(), walk(), level_segments(), level_boxes().
Version 3 (CELLMAP_V3.md): slopes (a [slope] section: four corner rises a cell) and map packs
(a .cellpack file naming a level's maps: stacked in one place, or joined by doors):
slope(), rise_at(), steep(), read_pack(), pack_stand_at(), pack_walk(), pack_doors(), pack_enter(), pack_segments(); level_segments() draws slopes.
"""
import copy
import colorsys, json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
B36 = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'

# ------------------------------------------------------------------ the tag table
# char, name, solid (blocks walking), default height (0-35, 9 = full wall), group
TAGS = [
    (' ', 'void (nothing, outside the map)', 0, 0, 'space'),
    ('!', 'potion / health', 0, 0, 'item'),
    ('"', 'web', 0, 0, 'hazard'),
    ('#', 'wall', 1, 9, 'structure'),
    ('$', 'gold', 0, 0, 'item'),
    ('%', 'food', 0, 0, 'item'),
    ('&', 'boss', 1, 0, 'actor'),
    ("'", 'open door', 0, 9, 'structure'),
    ('(', 'tool', 0, 0, 'item'),
    (')', 'weapon', 0, 0, 'item'),
    ('*', 'gem', 0, 0, 'item'),
    ('+', 'door (closed)', 1, 9, 'structure'),
    (',', 'grass', 0, 0, 'floor'),
    ('-', 'bridge', 0, 0, 'floor'),
    ('.', 'floor', 0, 0, 'floor'),
    ('/', 'lever', 0, 2, 'device'),
    ('0', 'boulder', 1, 5, 'structure'),
    ('1', 'waypoint 1', 0, 0, 'marker'), ('2', 'waypoint 2', 0, 0, 'marker'),
    ('3', 'waypoint 3', 0, 0, 'marker'), ('4', 'waypoint 4', 0, 0, 'marker'),
    ('5', 'waypoint 5', 0, 0, 'marker'), ('6', 'waypoint 6', 0, 0, 'marker'),
    ('7', 'waypoint 7', 0, 0, 'marker'), ('8', 'waypoint 8', 0, 0, 'marker'),
    ('9', 'waypoint 9', 0, 0, 'marker'),
    (':', 'rubble', 0, 1, 'floor'),
    (';', 'fish / water creature', 0, 0, 'actor'),
    ('<', 'stairs up', 0, 4, 'structure'),
    ('=', 'fence', 1, 3, 'structure'),
    ('>', 'stairs down', 0, 0, 'structure'),
    ('?', 'text / sign / scroll', 0, 0, 'item'),
    ('@', 'player start', 0, 0, 'marker'),
    ('A', 'altar', 1, 2, 'device'),
    ('B', 'bed', 1, 1, 'furniture'),
    ('C', 'chest', 1, 2, 'item'),
    ('D', 'door (locked)', 1, 9, 'structure'),
    ('E', 'enemy', 1, 0, 'actor'),
    ('F', 'fire', 0, 0, 'hazard'),
    ('G', 'guard', 1, 0, 'actor'),
    ('H', 'health station', 0, 3, 'device'),
    ('I', 'ice', 0, 0, 'floor'),
    ('J', 'jump pad', 0, 0, 'device'),
    ('K', 'key', 0, 0, 'item'),
    ('L', 'lava', 0, 0, 'hazard'),
    ('M', 'monster spawner', 1, 2, 'device'),
    ('N', 'NPC / companion', 1, 0, 'actor'),
    ('O', 'arch (opening)', 0, 9, 'structure'),
    ('P', 'pit', 0, 0, 'hazard'),
    ('Q', 'quest giver', 1, 0, 'actor'),
    ('R', 'ramp', 0, 4, 'structure'),
    ('S', 'switch', 0, 2, 'device'),
    ('T', 'teleporter', 0, 0, 'device'),
    ('U', 'upgrade', 0, 0, 'item'),
    ('V', 'vent', 0, 0, 'device'),
    ('W', 'window', 1, 9, 'structure'),
    ('X', 'exit / goal', 0, 0, 'marker'),
    ('Y', 'ladder', 0, 9, 'structure'),
    ('Z', 'zone trigger', 0, 0, 'marker'),
    ('[', 'armour', 0, 0, 'item'),
    ('\\', 'throne', 1, 3, 'furniture'),
    (']', 'shelf', 1, 6, 'furniture'),
    ('^', 'trap', 0, 0, 'hazard'),
    ('_', 'step (low block)', 0, 1, 'structure'),
    ('`', 'stone', 0, 1, 'floor'),
    ('a', 'ammo', 0, 0, 'item'),
    ('b', 'barrel', 1, 3, 'furniture'),
    ('c', 'crate', 1, 3, 'furniture'),
    ('d', 'debris', 0, 1, 'floor'),
    ('e', 'energy cell', 0, 0, 'item'),
    ('f', 'plant', 0, 0, 'floor'),
    ('g', 'gas', 0, 0, 'hazard'),
    ('h', 'hole in the ceiling', 0, 0, 'structure'),
    ('i', 'info terminal', 1, 3, 'device'),
    ('j', 'jar', 1, 1, 'furniture'),
    ('k', 'keycard', 0, 0, 'item'),
    ('l', 'lamp', 0, 0, 'device'),
    ('m', 'map piece', 0, 0, 'item'),
    ('n', 'noise maker', 1, 2, 'device'),
    ('o', 'ball / orb', 0, 0, 'item'),
    ('p', 'pressure plate', 0, 0, 'device'),
    ('q', 'quicksand', 0, 0, 'hazard'),
    ('r', 'rat', 0, 0, 'actor'),
    ('s', 'spikes', 0, 1, 'hazard'),
    ('t', 'torch', 0, 0, 'device'),
    ('u', 'unknown', 0, 0, 'marker'),
    ('v', 'vine', 0, 9, 'structure'),
    ('w', 'water (shallow)', 0, 0, 'floor'),
    ('x', 'dig spot', 0, 0, 'marker'),
    ('y', 'camera / sensor', 0, 6, 'device'),
    ('z', 'zombie', 1, 0, 'actor'),
    ('{', 'fountain', 1, 2, 'device'),
    ('|', 'pillar', 1, 9, 'structure'),
    ('}', 'water (deep)', 0, 0, 'hazard'),
    ('~', 'tunnel (roofed hallway)', 0, 0, 'structure'),
]

# what the cell DOES when an actor touches or enters it (the owner, 11 14 2026: "as a TAG it
# defines the function/effect of the cell"). Effect words are a small vocabulary a game reads:
#   none, block, open, locked (needs a key), damage, kill, heal, give (picked up), teleport,
#   climb, slide, slow, swim, launch, fall, trigger, spawn, talk, start, goal, path, text, light, roof
EFFECTS = {
    ' ': 'none', '!': 'heal', '"': 'slow', '#': 'block', '$': 'give', '%': 'heal', '&': 'damage',
    "'": 'path', '(': 'give', ')': 'give', '*': 'give', '+': 'open', ',': 'path', '-': 'path',
    '.': 'path', '/': 'trigger', '0': 'block', ':': 'slow', ';': 'damage', '<': 'climb',
    '=': 'block', '>': 'fall', '?': 'text', '@': 'start', 'A': 'trigger', 'B': 'heal', 'C': 'give',
    'D': 'locked', 'E': 'damage', 'F': 'damage', 'G': 'damage', 'H': 'heal', 'I': 'slide',
    'J': 'launch', 'K': 'give', 'L': 'kill', 'M': 'spawn', 'N': 'talk', 'O': 'path', 'P': 'fall',
    'Q': 'talk', 'R': 'climb', 'S': 'trigger', 'T': 'teleport', 'U': 'give', 'V': 'launch',
    'W': 'block', 'X': 'goal', 'Y': 'climb', 'Z': 'trigger', '[': 'give', '\\': 'block',
    ']': 'block', '^': 'damage', '_': 'climb', '`': 'path', 'a': 'give', 'b': 'block', 'c': 'block',
    'd': 'slow', 'e': 'give', 'f': 'path', 'g': 'damage', 'h': 'light', 'i': 'text', 'j': 'block',
    'k': 'give', 'l': 'light', 'm': 'give', 'n': 'trigger', 'o': 'give', 'p': 'trigger', 'q': 'slow',
    'r': 'damage', 's': 'damage', 't': 'light', 'u': 'none', 'v': 'climb', 'w': 'slow', 'x': 'trigger',
    'y': 'trigger', 'z': 'damage', '{': 'heal', '|': 'block', '}': 'swim', '~': 'roof',
    '1': 'path', '2': 'path', '3': 'path', '4': 'path', '5': 'path', '6': 'path', '7': 'path',
    '8': 'path', '9': 'path',
}

# R, G, B, Y, M, C again and again, a new shade every round: neighbours never share a hue
HUES = [0, 120, 225, 55, 300, 180]
SHADES = [(0.80, 1.00), (0.55, 0.85), (0.95, 0.70), (0.40, 1.00), (0.65, 0.55), (0.30, 0.95)]


def colour(i):
    h = HUES[i % 6] / 360.0
    s, v = SHADES[(i // 6) % len(SHADES)]
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return '#%02X%02X%02X' % (round(r * 255), round(g * 255), round(b * 255))


def tag_table():
    """all 256 codes in order: the named tags, then 'custom <code>' for the rest"""
    named = {ord(t[0]): t for t in TAGS}
    out = []
    for code in range(256):
        t = named.get(code)
        if t:
            out.append(dict(code=code, char=t[0], name=t[1], solid=t[2], height=t[3], group=t[4],
                            effect=EFFECTS.get(t[0], 'none')))
        else:
            out.append(dict(code=code, char=chr(code) if code >= 161 else '', name='custom %d' % code,
                            solid=0, height=0, group='custom', effect='none'))
    for i, t in enumerate(out):
        t['colour'] = colour(i)
    return out


def write_tags(path=None):
    path = path or os.path.join(ROOT, 'data', 'tags_default.txt')
    lines = ['# cellmap tag table: code, char (empty = not printable), name, colour, solid, height (0-35), group, effect',
             '# effect = what the cell does when an actor touches or enters it: ' + ', '.join(sorted(set(EFFECTS.values()))),
             '# Colours are data, not code: change any; regenerate with "cellmap.py tags" (R G B Y M C, a new shade a round).']
    for t in tag_table():
        lines.append('\t'.join(str(t[k]) for k in ('code', 'char', 'name', 'colour', 'solid', 'height', 'group', 'effect')))
    open(path, 'w', encoding='utf-8', newline='\n').write('\n'.join(lines) + '\n')
    return path


# ------------------------------------------------------------------ fonts
def json_to_font(src, dst):
    """BitFontMaker2 .json ({"65": [16 row numbers]}) -> .font.txt: 'code<TAB>r1,r2,...' (LIB_BIT Bit.FromRows rows)"""
    d = json.load(open(src, encoding='utf-8'))
    lines = ['# 1-bit font for cellmap: code <tab> 16 rows (BitFontMaker2: column 1 = 1, column 2 = 2 ...)',
             'name\t%s' % d.get('name', os.path.basename(src)), 'size\t16']
    for k in sorted((k for k in d if k.lstrip('-').isdigit() and int(k) >= 0), key=int):
        if int(k) < 256 and isinstance(d[k], list):
            lines.append('%s\t%s' % (k, ','.join(str(int(v)) for v in d[k])))
    open(dst, 'w', encoding='utf-8', newline='\n').write('\n'.join(lines) + '\n')
    return dst


def read_font(path):
    font = {'glyph': {}}
    for line in open(path, encoding='utf-8'):
        line = line.rstrip('\n')
        if not line or line.startswith('#'):
            continue
        k, v = line.split('\t', 1)
        if k.isdigit():
            font['glyph'][int(k)] = [int(x) for x in v.split(',')]
        else:
            font[k] = v
    return font


def glyph_rows(font, code, size=16):
    """a glyph as LIB_BIT text rows of 0/1"""
    rows = font['glyph'].get(code, [0] * size)
    return [''.join('1' if r >> c & 1 else '0' for c in range(size)) for r in rows]


# ------------------------------------------------------------------ the map file
DEFAULT_META = dict(name='untitled', cols=13, rows=13, cell=76, wallH=58, unitPx=16,
                    font='Aquarius', tags='tags_default', version=1)

# ------------------------------------------------------------------ auto walls (Aquarius line pieces)
# a wall cell takes the piece that joins its full-height neighbours: N=1 E=2 S=4 W=8
# (Aquarius / AquaDouble codes: 172 -, 214 |, 207 L, 222 r, 206 7, 223 J, 205 |-, 221 -|,
#  220 T, 204 _|_, 200 +, 198 a lone block)
AUTO_WALL = [198, 214, 172, 207, 214, 214, 222, 205, 172, 223, 172, 204, 206, 221, 220, 200]


def autowall(m, wall_tag='#', full=9):
    """give every wall cell (tag '#') whose design is plain '#' or an earlier line piece the line
    piece that joins its full-height neighbours; hand-made designs (letters) are kept"""
    rows, cols = m['meta']['rows'], m['meta']['cols']
    pieces = set(AUTO_WALL) | {ord(wall_tag)}
    def tall(r, c):
        return 0 <= r < rows and 0 <= c < cols and height1(m, r, c) >= full
    for r in range(rows):
        for c in range(cols):
            if m['tags'][r][c] != wall_tag or m['design'][r][c] not in pieces:
                continue
            mask = tall(r - 1, c) * 1 + tall(r, c + 1) * 2 + tall(r + 1, c) * 4 + tall(r, c - 1) * 8
            m['design'][r][c] = AUTO_WALL[mask]
    return m


def onebit_rows(m, font, scale=1, invert=False):
    """the whole map as one 1-bit picture: each cell's design glyph (16 x 16), scaled; rows of 0/1"""
    size = 16
    out = []
    cache = {}
    for r in range(m['meta']['rows']):
        for g in range(size):
            line = []
            for c in range(m['meta']['cols']):
                code = m['design'][r][c]
                if code not in cache:
                    cache[code] = glyph_rows(font, code, size)
                bits = cache[code][g]
                if invert:
                    bits = bits.translate(str.maketrans('01', '10'))
                line.append(''.join(b * scale for b in bits))
            row = ''.join(line)
            out.extend([row] * scale)
    return out


def new_map(cols=13, rows=13, **meta):
    m = dict(meta=dict(DEFAULT_META, cols=cols, rows=rows, **meta))
    m['design'] = [[ord('.')] * cols for _ in range(rows)]
    m['tags'] = [['.'] * cols for _ in range(rows)]
    m['heights'] = [[0] * cols for _ in range(rows)]
    m['tagdefs'] = {}
    return m


def printable(code):
    return 32 <= code <= 126 or 161 <= code <= 255


META_ORDER = ['name', 'cols', 'rows', 'cell', 'wallH', 'unitPx', 'font', 'tags', 'version']
LAYERS2 = ['floor', 'ceiling', 'red', 'green', 'blue', 'from']     # from: per cell, 1 From Floor + 2 From Ceiling (3b)
SECTIONS = ['map', 'design', 'design hex', 'tags', 'heights', 'tagdefs'] + LAYERS2 + ['links', 'objects', 'stack', 'slope']
V2_DEFAULTS = dict(base=0, step=30, head=83, relief=6, slab=10, steep=60)


def version(m):
    return int(m['meta'].get('version', 1))


def map_text(m):
    v = version(m)
    out = ['# cellmap %d - LIB_BIT/editor (format: editor/%s)' % (v, 'CELLMAP_V3.md' if v >= 3 else 'CELLMAP_V2.md' if v >= 2 else 'README.md'), '[map]']
    keys = [k for k in META_ORDER if k in m['meta']] + sorted(k for k in m['meta'] if k not in META_ORDER)
    out += ['%s\t%s' % (k, m['meta'][k]) for k in keys]
    if all(printable(c) for row in m['design'] for c in row):
        out.append('[design]')
        out += [''.join(chr(c) for c in row) for row in m['design']]
    else:
        out.append('[design hex]')
        out += [' '.join('%02X' % c for c in row) for row in m['design']]
    out.append('[tags]')
    out += [''.join(row) for row in m['tags']]
    if v < 2:
        out.append('[heights]')
        out += [''.join(B36[h] for h in row) for row in m['heights']]
    else:
        for layer in LAYERS2:
            if layer in ('red', 'green', 'blue', 'from') and not any(x for row in m[layer] for x in row):
                continue                                    # all zeros: left out
            out.append('[%s]' % layer)
            out += [' '.join('%3d' % x for x in row) for row in m[layer]]
        if m.get('links'):
            out.append('[links]')
            out += ['\t'.join([k['from'], k['type'], k['to'], k.get('note', '')]) for k in m['links']]
        if m.get('objects'):
            out.append('[objects]')
            out += ['\t'.join([o['id'], o['kind'], o['at'], str(o['facing']), str(o['above']), o.get('props', '')]) for o in m['objects']]
        if m.get('stack'):
            out.append('[stack]')
            out += ['\t'.join([k['file'], str(k['base']), k['at']]) for k in m['stack']]
        if m.get('slope'):
            out.append('[slope]')
            out += ['%d,%d\t%s' % (c + 1, r + 1, ' '.join(str(x) for x in m['slope'][r, c])) for r, c in sorted(m['slope'])]
    if m.get('tagdefs'):
        out.append('[tagdefs]')
        for ch, t in sorted(m['tagdefs'].items()):
            out.append('\t'.join([ch, t['name'], t['colour'], str(t['solid']), str(t['height']), t.get('effect', 'none')]))
    return '\n'.join(out) + '\n'


def write_map(m, path):
    open(path, 'w', encoding='utf-8', newline='\n').write(map_text(m))


def read_map(path):
    """reads version 1 and version 2 files; a version 1 map stays version 1 (see upgrade)"""
    m = dict(meta={}, design=[], tags=[], heights=[], tagdefs={}, links=[], objects=[], stack=[], slope={})
    for layer in LAYERS2:
        m[layer] = []
    sec = None
    for line in open(path, encoding='utf-8'):
        line = line.rstrip('\n').rstrip('\r')
        if line.startswith('#') and sec in (None, 'map'):       # rows and tag defs may start with '#'
            continue
        if line.startswith('[') and line.endswith(']') and line[1:-1] in SECTIONS:
            sec = line[1:-1]
            continue
        if sec == 'map' and '\t' in line:
            k, v = line.split('\t', 1)
            m['meta'][k] = int(v) if v.lstrip('-').isdigit() else v
        elif sec == 'design':
            m['design'].append([ord(c) for c in line])
        elif sec == 'design hex':
            m['design'].append([int(x, 16) for x in line.split()])
        elif sec == 'tags':
            m['tags'].append(list(line))
        elif sec == 'heights':
            m['heights'].append([B36.index(c) for c in line])
        elif sec in LAYERS2:
            m[sec].append([int(x) for x in line.split()])
        elif sec == 'links' and line:
            f = (line.split('\t') + ['', '', '', ''])[:4]
            m['links'].append(dict(zip(('from', 'type', 'to', 'note'), f)))
        elif sec == 'objects' and line:
            f = (line.split('\t') + [''] * 6)[:6]
            m['objects'].append(dict(zip(('id', 'kind', 'at', 'facing', 'above', 'props'), f)))
        elif sec == 'stack' and line:
            f = (line.split('\t') + [''] * 3)[:3]
            m['stack'].append(dict(zip(('file', 'base', 'at'), f)))
        elif sec == 'slope' and line:
            f = line.split('\t')                            # col,row <tab> nw ne se sw <tab> what (only ground)
            at, rises = f[0].split(','), (f[1].split() if len(f) > 1 else [])
            if len(f) > 2 and f[2] not in ('', 'ground'):
                continue
            if len(at) == 2 and len(rises) == 4:
                m['slope'][int(at[1]) - 1, int(at[0]) - 1] = [int(x) for x in rises]
        elif sec == 'tagdefs' and line:
            f = line.split('\t')
            m['tagdefs'][f[0]] = dict(name=f[1], colour=f[2], solid=int(f[3]), height=int(f[4]),
                                      effect=f[5] if len(f) > 5 else 'none')
    cols, rows = m['meta'].get('cols', 0), m['meta'].get('rows', 0)
    pads = [('design', 32), ('tags', ' ')]
    if version(m) < 2:
        pads.append(('heights', 0))
        for layer in LAYERS2:
            del m[layer]
    else:
        del m['heights']
        pads += [(layer, 0) for layer in LAYERS2]
    for layer, pad in pads:                                 # short or missing rows filled out
        m[layer] = [row + [pad] * (cols - len(row)) for row in m[layer]]
        while len(m[layer]) < rows:
            m[layer].append([pad] * cols)
    return m


# ------------------------------------------------------------------ version 2: heights (CELLMAP_V2.md)
def h1_to_floor(h, tag='.'):
    """a version 1 height (0-35, 9 = a full wall) as a version 2 floor (hu, 100 = a full wall)"""
    if h <= 0:
        return 0 if tag == ' ' else 1
    return min(255, int(h * 100 / 9 + 0.5))


def floor_to_h1(f):
    if f <= 1:
        return 0
    return min(35, max(1, int(f * 9 / 100 + 0.5)))


def height1(m, r, c):
    """the old 0-35 height of a cell (0-based row, col), whatever the map's version"""
    return m['heights'][r][c] if version(m) < 2 else floor_to_h1(m['floor'][r][c])


def upgrade(m):
    """a version 1 map as version 2, in place: heights become floors; nothing else is built"""
    if version(m) >= 2:
        return m
    rows, cols = m['meta']['rows'], m['meta']['cols']
    m['floor'] = [[h1_to_floor(m['heights'][r][c], m['tags'][r][c]) for c in range(cols)] for r in range(rows)]
    for layer in LAYERS2[1:]:
        m[layer] = [[0] * cols for _ in range(rows)]
    del m['heights']
    m['meta']['version'] = 2
    for k in ('links', 'objects', 'stack'):
        m.setdefault(k, [])
    m.setdefault('slope', {})
    return m


def new_map2(cols, rows, **meta):
    return upgrade(new_map(cols, rows, **meta))


def opt(m, key):
    v = m['meta'].get(key, V2_DEFAULTS[key])
    return v if isinstance(v, (int, float)) else float(v)


def tag_lookup(tags=None):
    """{char: tag record} from a tag_table() list"""
    return {t['char']: t for t in (tags or tag_table()) if t['char']}


def tag_info(m, tags, ch, key):
    d = m.get('tagdefs', {}).get(ch)
    if d and d.get(key) not in (None, ''):
        return d[key]
    return tags.get(ch, {}).get(key, 'none' if key == 'effect' else '')


def is_water(m, tags, r, c):
    return m['red'][r][c] > 0 and str(tag_info(m, tags, m['tags'][r][c], 'name')).startswith('water')


BAND = 255          # one colour band (CELLMAP_V2.md 3b): white 0-255, green 255-510, blue 510-765
TOP = 3 * BAND      # the map's top when it names none: the top of the blue band


def from_flags(m, r, c):
    """the cell's From Floor (1) / From Ceiling (2) flags, 0-3"""
    return m['from'][r][c] if m.get('from') else 0


def column(m, r, c):
    """a cell's column in hu, or None for empty space / outside: a 7-tuple
    ground, roof bottom, roof top (None, None with no roof), then up to two floating blocks
    (bottom, top; None, None when missing), lowest first. CELLMAP_V2.md section 3b."""
    if not (0 <= r < m['meta']['rows'] and 0 <= c < m['meta']['cols']):
        return None
    f, cl, rd, g, b = (m[k][r][c] for k in LAYERS2[:5])
    if f <= 0:
        return None
    ground = f - rd
    roof = [cl, cl] if cl > 0 else None
    slab = opt(m, 'slab')
    blocks = [[BAND * k + v - slab, BAND * k + v] for k, v in ((1, g), (2, b)) if v > 0]
    flags = from_flags(m, r, c)
    if flags & 2:               # From Ceiling: solid from the map's top down to the roof, else the lowest block
        top = max([map_top(m)] + [t for _, t in blocks])
        if roof:
            roof, blocks = [roof[0], max(roof[1], top)], []
        elif blocks:
            blocks = [[blocks[0][0], top]]
    if flags & 1 and (blocks or (flags & 2 and roof)):
        # From Floor: solid from the ground up to the highest block (roof and air under it filled)
        ground = max([ground] + [t for _, t in blocks] + ([roof[1]] if roof else []))
        roof, blocks = None, []
    merged = []                 # a block that touches what is under it joins it
    for bb, bt in blocks:
        if bb <= ground and (roof is None or roof[0] > ground):
            ground = max(ground, bt)
        elif roof and bb <= roof[1] and bt >= roof[0]:
            roof = [min(roof[0], bb), max(roof[1], bt)]
        elif merged and bb <= merged[-1][1]:
            merged[-1][1] = max(merged[-1][1], bt)
        else:
            merged.append([bb, bt])
    out = [ground] + (roof or [None, None])
    for bb, bt in merged:
        out += [bb, bt]
    return tuple(out + [None] * (7 - len(out)))


def solids(col):
    """the column's solid parts above the ground: [(bottom, top)], roof and blocks, lowest first"""
    parts = [(col[i], col[i + 1]) for i in (1, 3, 5) if col[i] is not None]
    return sorted(parts)


def blocks_of(col):
    """the floating blocks of a column: [(bottom, top)]"""
    return [(col[i], col[i + 1]) for i in (3, 5) if col[i] is not None]


def map_top(m):
    """the map's top in hu (where From Ceiling blocks reach): its own `top`, else TOP (765)"""
    t = m['meta'].get('top')
    return t if isinstance(t, (int, float)) else TOP


NO_ROOF = 9999
OPEN_SKY = 5000                 # air above this much is open sky (a slope or a raised glyph takes a little off 9999)


def levels(m, r, c):
    """where an actor can stand in a cell: [(top, air above)] in hu, lowest first"""
    return levels_of(column(m, r, c))


def has_relief(m, r, c):
    col = column(m, r, c)
    if col is None or opt(m, 'relief') <= 0 or m['design'][r][c] in (32, 46) or slope(m, r, c):
        return False
    return m['red'][r][c] == 0 and col[0] < 100 and (col[1] is None or col[1] > col[0])


def shaped(m, font, r, c):
    """the map says `extrude glyph` and this cell's glyph can stand as the solid: the lit bits rise
    from the flat floor (1) to the cell's ground, the rest of the cell is flat floor
    (CELLMAP_V2.md section 4b). Not for blank glyphs, pits, or cells no higher than the floor."""
    if m['meta'].get('extrude') != 'glyph' or font is None:
        return False
    if not (0 <= r < m['meta']['rows'] and 0 <= c < m['meta']['cols']):
        return False
    if m['design'][r][c] in (32, 46) or m['red'][r][c] > 0 or slope(m, r, c):
        return False
    col = column(m, r, c)
    if col is None or col[0] <= 1:
        return False
    return any(font['glyph'].get(m['design'][r][c], [0] * 16))


def levels_of(col):
    """levels() from a column: the ground and the top of every solid part, each with the air
    up to the next part above (NO_ROOF over the highest); a top with no air over it is no level"""
    if col is None:
        return []
    parts = [(None, col[0])] + solids(col)
    out = []
    for k, (_, t) in enumerate(parts):
        air = parts[k + 1][0] - t if k + 1 < len(parts) else NO_ROOF
        if air > 0:
            out.append((t, air))
    return out


def lit_at(m, font, r, c, x, z):
    px = min(15, int((x / m['meta']['cell'] + m['meta']['cols'] / 2 - c) * 16))
    pz = min(15, int((z / m['meta']['cell'] + m['meta']['rows'] / 2 - r) * 16))
    return bool(font['glyph'].get(m['design'][r][c], [0] * 16)[pz] >> px & 1)


def cell_x(m, col):
    """engine x of the centre of column col (1-based, decimals allowed)"""
    return (col - 0.5 - m['meta']['cols'] / 2) * m['meta']['cell']


def cell_z(m, row):
    return (row - 0.5 - m['meta']['rows'] / 2) * m['meta']['cell']


def cell_at(m, x, z):
    """(col, row), 1-based, of an engine point (may be outside the map)"""
    import math
    return (math.floor(x / m['meta']['cell'] + m['meta']['cols'] / 2) + 1,
            math.floor(z / m['meta']['cell'] + m['meta']['rows'] / 2) + 1)


def hu(m):
    return m['meta']['wallH'] / 100.0


def pick(m, ex, ey, ez, dx, dy, dz, max_len):
    """the cell a ray meets first (painting in a 3D view): (col, row, what), what = ground, roof,
    slab or void (empty space inside the map, met at the flat floor's height); None = nothing.
    The ray starts at ex,ey,ez (engine units, y up), goes along dx,dy,dz for max_len units,
    looked at every eighth of a cell."""
    length = (dx * dx + dy * dy + dz * dz) ** 0.5
    if length == 0:
        return None
    step = m['meta']['cell'] / 8
    k, base = hu(m), opt(m, 'base')
    last = None
    for i in range(int(max_len / step) + 1):
        x, y, z = ex + dx * (i * step / length), ey + dy * (i * step / length), ez + dz * (i * step / length)
        yh = y / k - base
        lo, hi = (yh, yh) if last is None else (min(last, yh), max(last, yh))     # a thin block between two looks
        last = yh
        c, r = cell_at(m, x, z)
        inside = 1 <= c <= m['meta']['cols'] and 1 <= r <= m['meta']['rows']
        col = column(m, r - 1, c - 1) if inside else None
        if col is None:
            if yh <= 1:
                return (c, r, 'void') if inside else None
            continue
        if yh <= col[0]:
            return c, r, 'ground'
        if col[1] is not None and col[1] <= yh <= max(col[2], col[1] + 4):
            return c, r, 'roof'
        if any(lo <= bt and hi >= bb for bb, bt in blocks_of(col)):
            return c, r, 'slab'
    return None


def slope(m, r, c):
    """a cell's slope: [nw, ne, se, sw], hu each corner of its ground rises; None = flat (0-based row, col)"""
    return (m.get('slope') or {}).get((r, c))


def set_slope(m, r, c, rises=None):
    """slope a cell (four corner rises 0-255) or flatten it (None or all zeros); the map becomes version 3"""
    m.setdefault('slope', {})
    if not rises or not any(rises):
        m['slope'].pop((r, c), None)
        return
    upgrade(m)
    m['slope'][r, c] = [int(x) for x in rises]
    m['meta']['version'] = max(3, version(m))


def steep(m, r, c):
    """the cell's slope is too steep to walk up: its corners differ by more than `steep` hu"""
    s = slope(m, r, c)
    return bool(s) and max(s) - min(s) > opt(m, 'steep')


def rise_at(m, r, c, x, z):
    """hu the sloped ground of cell r,c stands above the cell's ground under engine point x,z"""
    s = slope(m, r, c)
    if not s:
        return 0
    u = min(1.0, max(0.0, x / m['meta']['cell'] + m['meta']['cols'] / 2 - c))
    v = min(1.0, max(0.0, z / m['meta']['cell'] + m['meta']['rows'] / 2 - r))
    return s[0] * (1 - u) * (1 - v) + s[1] * u * (1 - v) + s[2] * u * v + s[3] * (1 - u) * v


def point_levels(m, tags, font, x, z):
    """what stands under engine point x,z of ONE map, in the map's own hu: None over empty space,
    else dict(levels=[(top, air)] lowest first ([] when a tag blocks), steep, under (the lowest
    solid: a stacked map is a deck from here up to its ground), solid (the ground's top), r, c)"""
    col, row = cell_at(m, x, z)
    r, c = row - 1, col - 1
    col_ = column(m, r, c)
    if col_ is None:
        return None
    is_shaped = shaped(m, font, r, c)
    is_open = False                 # extrude glyph: off the lit bits the cell is flat floor
    if is_shaped and not lit_at(m, font, r, c, x, z):
        is_open = True
        col_ = (1,) + tuple(col_[1:])
    out = dict(steep=steep(m, r, c), under=min(0, col_[0]), solid=col_[0], r=r, c=c, levels=[])
    effect = tag_info(m, tags, m['tags'][r][c], 'effect')
    if effect == 'locked' or (effect == 'block' and not is_open):
        return out
    for i, (top, air) in enumerate(levels_of(col_)):
        if i == 0:
            if slope(m, r, c):
                up = rise_at(m, r, c, x, z)
                top += up
                air -= up
                out['solid'] = top
            elif font is not None and not is_shaped and has_relief(m, r, c) and lit_at(m, font, r, c, x, z):
                top += opt(m, 'relief')
                air -= opt(m, 'relief')
        out['levels'].append((top, air))
    return out


def stand_at(m, tags, font, x, z, y, centre=False):
    """the height (engine units) an actor now at height y would stand at on point x,z; None = cannot.
    Blocked by: outside, empty space, a tag whose effect is block or locked, a rise over `step`,
    less than `head` of air. centre (the actor's middle, not its rim): no rise at all on a steep slope."""
    p = point_levels(m, tags, font, x, z)
    if p is None or not p['levels']:
        return None
    yh = y / hu(m) - opt(m, 'base')
    best = None
    for i, (top, air) in enumerate(p['levels']):
        rise = 0.01 if (centre and i == 0 and p['steep']) else opt(m, 'step') + 1e-6
        if top <= yh + rise and air >= opt(m, 'head') and (air >= OPEN_SKY or yh <= top + air + 1e-6):
            best = top                                  # the last test: a drop goes through air only, never through a roof
    return None if best is None else (best + opt(m, 'base')) * hu(m)


def ground_at(m, tags, font, x, z, y=1e9):
    """the highest standing height at x,z at or below y (engine units); None over empty space"""
    return stand_at(m, tags, font, x, z, y)


def walk(m, tags, font, x, z, y, dx, dz, radius=12):
    """move an actor (a circle) by dx,dz, sliding along what blocks it: (x, z, y, effect of the cell it is in).
    On a steep slope a `path` or `none` cell answers `slide`."""
    def fits(nx, nz):
        for ax in (-radius, radius):
            for az in (-radius, radius):
                if stand_at(m, tags, font, nx + ax, nz + az, y) is None and stand_at(m, tags, font, x + ax, z + az, y) is not None:
                    return None                             # its rim would enter a wall (a rim already in one, after a drop, may leave)
        return stand_at(m, tags, font, nx, nz, y, True)
    for tx, tz in ((dx, dz), (dx, 0), (0, dz)):
        ny = fits(x + tx, z + tz)
        if ny is not None and (tx or tz):
            x, z, y = x + tx, z + tz, ny
            break
    col, row = cell_at(m, x, z)
    effect = tag_info(m, tags, m['tags'][row - 1][col - 1], 'effect')
    if effect in ('path', 'none') and steep(m, row - 1, col - 1):
        effect = 'slide'
    return x, z, y, effect


# ------------------------------------------------------------------ version 3: map packs (CELLMAP_V3.md)
def pack_text(pack):
    out = ['# cellpack 1 - LIB_BIT/editor (format: editor/CELLMAP_V3.md)', '[pack]']
    out += ['%s\t%s' % (k, pack['meta'][k]) for k in ['name', 'start'] if k in pack['meta']]
    out += ['%s\t%s' % (k, pack['meta'][k]) for k in sorted(pack['meta']) if k not in ('name', 'start')]
    out.append('[maps]')
    out += ['\t'.join([e['id'], e['file'], e['place'], str(e['base']), e['at']]) for e in pack['maps']]
    if pack['doors']:
        out.append('[doors]')
        out += ['\t'.join([d['from'], d['type'], d['to'], d.get('note', '')]) for d in pack['doors']]
    return '\n'.join(out) + '\n'


def read_pack(path, load=True):
    """a .cellpack file: dict(meta, maps=[dict(id, file, place, base, at, map, ox, oz)], doors, problems).
    Map files are named from the pack's own folder (never absolute, never ..). A plain .cellmap
    reads as a pack of one map (id = its name), its [stack] lines as the maps over it."""
    here = os.path.dirname(os.path.abspath(path))
    pack = dict(meta={}, maps=[], doors=[], problems=[], path=path)
    if path.endswith('.cellmap'):
        m = read_map(path)
        pack['meta'] = dict(name=m['meta'].get('name', ''), start=m['meta'].get('name', 'map'))
        pack['maps'].append(dict(id=m['meta'].get('name', 'map'), file=os.path.basename(path), place='main',
                                 base=m['meta'].get('base', 0), at='1,1'))
        for n, k in enumerate(m.get('stack', [])):
            pack['maps'].append(dict(id='stack%d' % (n + 1), file=k['file'], place='main', base=k['base'], at=k['at']))
    else:
        sec = None
        for line in open(path, encoding='utf-8'):
            line = line.rstrip('\n').rstrip('\r')
            if not line or line.startswith('#'):
                continue
            if line in ('[pack]', '[maps]', '[doors]'):
                sec = line[1:-1]
                continue
            f = line.split('\t')
            if sec == 'pack' and len(f) > 1:
                pack['meta'][f[0]] = f[1]
            elif sec == 'maps':
                f = (f + [''] * 5)[:5]
                pack['maps'].append(dict(id=f[0], file=f[1], place=f[2] or 'main', base=f[3] or 0, at=f[4] or '1,1'))
            elif sec == 'doors':
                f = (f + [''] * 4)[:4]
                pack['doors'].append(dict(zip(('from', 'type', 'to', 'note'), f)))
    first = {}
    for e in pack['maps']:
        e['base'] = int(e['base']) if str(e['base']).lstrip('-').isdigit() else float(e['base'])
        e['map'], e['ox'], e['oz'] = None, 0.0, 0.0
        f = e['file'].replace('\\', '/')
        if f.startswith('/') or ':' in f or '..' in f.split('/'):
            pack['problems'].append('%s: the file must be inside the pack\'s folder: %s' % (e['id'], e['file']))
            continue
        if not load:
            continue
        if not os.path.isfile(os.path.join(here, f)):
            pack['problems'].append('%s: no file %s' % (e['id'], e['file']))
            continue
        m = upgrade(read_map(os.path.join(here, f)))
        m['meta']['base'] = e['base']                       # the pack places the map
        e['map'] = m
        g = first.setdefault(e['place'], e)                 # a place's first map is centred on 0,0
        ac, ar = (int(v) for v in e['at'].split(','))
        gc, gr = (int(v) for v in g['at'].split(','))
        cell = g['map']['meta']['cell']
        e['ox'] = (ac - gc + m['meta']['cols'] / 2 - g['map']['meta']['cols'] / 2) * cell
        e['oz'] = (ar - gr + m['meta']['rows'] / 2 - g['map']['meta']['rows'] / 2) * cell
        if (m['meta']['cell'], m['meta']['wallH']) != (cell, g['map']['meta']['wallH']):
            pack['problems'].append('%s: cell and wallH differ from %s in the same place' % (e['id'], g['id']))
    ids = [e['id'] for e in pack['maps']]
    for d in pack['doors']:
        for end in (d['from'], d['to']):
            if end.split(':')[0] not in ids:
                pack['problems'].append('door %s -> %s: no map %s' % (d['from'], d['to'], end.split(':')[0]))
    return pack


def pack_map(pack, map_id):
    for e in pack['maps']:
        if e['id'] == map_id:
            return e
    return None


def pack_place(pack, place):
    """the loaded maps of one place, in the pack's order (the first is the place's ground map)"""
    return [e for e in pack['maps'] if e['place'] == place and e['map'] is not None]


def pack_stand_at(pack, place, tags, font, x, z, y, centre=False):
    """stand_at over every map stacked in a place: (height in engine units, map id), or None.
    Each map offers its levels; another map's solid above a level is its roof."""
    es = pack_place(pack, place)
    if not es:
        return None
    g = es[0]['map']
    k, step, head = hu(g), opt(g, 'step'), opt(g, 'head')
    pts = []
    for e in es:
        p = point_levels(e['map'], tags, font, x - e['ox'], z - e['oz'])
        if p is not None:
            pts.append((e, p))
    yh = y / k
    best = None
    for e, p in pts:
        for i, (top, air) in enumerate(p['levels']):
            top += e['base']
            for e2, p2 in pts:
                if e2 is e:
                    continue
                lo, hi = e2['base'] + p2['under'], e2['base'] + p2['solid']
                if lo >= top - 1e-6:
                    air = min(air, lo - top)
                elif hi > top + 1e-6:
                    air = 0                                 # inside the other map's solid
            rise = 0.01 if (centre and i == 0 and p['steep']) else step + 1e-6
            if top <= yh + rise and air >= head and (air >= OPEN_SKY or yh <= top + air + 1e-6) and (best is None or top > best[0]):
                best = (top, e['id'])
    return None if best is None else (best[0] * k, best[1])


def pack_walk(pack, place, tags, font, x, z, y, dx, dz, radius=12):
    """walk() over the maps stacked in a place: (x, z, y, effect, map id, col, row) of the cell stood on"""
    def fits(nx, nz):
        for ax in (-radius, radius):
            for az in (-radius, radius):
                if pack_stand_at(pack, place, tags, font, nx + ax, nz + az, y) is None and \
                        pack_stand_at(pack, place, tags, font, x + ax, z + az, y) is not None:
                    return None
        return pack_stand_at(pack, place, tags, font, nx, nz, y, True)
    on = pack_stand_at(pack, place, tags, font, x, z, y + 0.001, True)
    for tx, tz in ((dx, dz), (dx, 0), (0, dz)):
        got = fits(x + tx, z + tz)
        if got is not None and (tx or tz):
            x, z, y, on = x + tx, z + tz, got[0], got
            break
    if on is None:
        return x, z, y, 'none', '', 0, 0
    e = pack_map(pack, on[1])
    col, row = cell_at(e['map'], x - e['ox'], z - e['oz'])
    effect = tag_info(e['map'], tags, e['map']['tags'][row - 1][col - 1], 'effect')
    if effect in ('path', 'none') and steep(e['map'], row - 1, col - 1):
        effect = 'slide'
    return x, z, y, effect, e['id'], col, row


def pack_doors(pack, map_id, col, row):
    """the doors leaving a cell: [dict(from, type, to, note)] (to = 'map:col,row')"""
    return [d for d in pack['doors'] if d['from'] == '%s:%d,%d' % (map_id, col, row)]


def pack_enter(pack, tags, font, where):
    """arrive at 'map:col,row' (a door's `to`, or the pack's start map's @ cell when where is None):
    (place, x, z, y) in engine units, standing in the middle of the cell; None when there is no such place to stand"""
    if where is None:
        e = pack_map(pack, pack['meta'].get('start', '')) or (pack['maps'][0] if pack['maps'] else None)
        if e is None or e['map'] is None:
            return None
        spots = [(c + 1, r + 1) for r, row in enumerate(e['map']['tags']) for c, t in enumerate(row) if t == '@']
        col, row = spots[0] if spots else (1, 1)
    else:
        e = pack_map(pack, where.split(':')[0])
        if e is None or e['map'] is None:
            return None
        col, row = (float(v) for v in where.split(':')[1].split(','))
    m = e['map']
    x, z = cell_x(m, col), cell_z(m, row)
    p = point_levels(m, tags, font, x, z)
    if p is None or not p['levels']:
        return None
    return e['place'], x + e['ox'], z + e['oz'], (p['levels'][0][0] + e['base']) * hu(m)


# ------------------------------------------------------------------ the checker (E12, CELLMAP_V3.md 2 and 6)
# One problem a line: kind TAB map id TAB col,row TAB plain words, in a fixed order (the checks in
# the order below, maps in the pack's order, cells row by row). The same lines in xTalk (CellMap.Check).
# Kinds: pack, start, link, slope-empty, slope-all, slope-roof, slope-trap, door, hole, step, unreachable.
# Reachability is the walker's rules cell by cell, on the ground of each cell (not a tower's roof top):
# up no more than `step`, at least `head` of air, a drop only through air, never up a steep slope;
# stacked maps of one place together; doors and teleport links join cells; locked doors open.

SIDES = ((-1, 0, 0, 1, 2), (0, 1, 1, 2, 3), (1, 0, 2, 3, 0), (0, -1, 3, 0, 1))    # dr, dc, this edge's corners, the side opposite
SIDE_WORDS = ('north', 'east', 'south', 'west')


def _edge_h(m, r, c, side, leaving):
    """hu (in the map) of a cell's ground at one edge: leaving = the highest point of the edge
    (none of a steep cell: it slides to its lowest), else the lowest point of the edge"""
    g = column(m, r, c)[0]
    s = slope(m, r, c)
    if not s:
        return g
    a, b = s[SIDES[side][2]], s[SIDES[side][3]]
    if leaving and steep(m, r, c):
        return g + min(s)
    return g + (max(a, b) if leaving else min(a, b))


def _cr(text):
    """'col,row' (decimals cut) as two whole numbers, or None"""
    f = text.split(',')
    if len(f) != 2:
        return None
    try:
        return int(float(f[0])), int(float(f[1]))
    except ValueError:
        return None


def _blocked(m, tags, r, c):
    return tag_info(m, tags, m['tags'][r][c], 'effect') == 'block'


def _check_one(m, tags, mid, out):
    rows, cols = m['meta']['rows'], m['meta']['cols']
    step = opt(m, 'step')

    def inside(c, r):
        return 1 <= c <= cols and 1 <= r <= rows

    at = _cr
    objs = [o['id'] for o in m.get('objects', [])]
    for k in m.get('links', []):
        a = at(k['from'])
        if a is None or not inside(*a):
            out.append(('link', mid, k['from'], 'a %s link from outside the map' % (k['type'] or 'plain')))
            continue
        tos = k['to'].split()
        if not tos:
            out.append(('link', mid, k['from'], 'a %s link with no target' % (k['type'] or 'plain')))
        for to in tos:
            if to.startswith('@'):
                if to[1:] not in objs:
                    out.append(('link', mid, k['from'], 'a %s link to %s: no such object' % (k['type'] or 'plain', to)))
            else:
                b = at(to)
                if b is None or not inside(*b):
                    out.append(('link', mid, k['from'], 'a %s link to %s: outside the map' % (k['type'] or 'plain', to)))
    for r in range(rows):
        for c in range(cols):
            s = slope(m, r, c)
            if not s:
                continue
            where = '%d,%d' % (c + 1, r + 1)
            col = column(m, r, c)
            if col is None:
                out.append(('slope-empty', mid, where, 'a slope on an empty cell does nothing'))
                continue
            if min(s) > 0:
                out.append(('slope-all', mid, where, 'all four corners lifted: raise the floor by %d instead' % min(s)))
            if col[1] is not None and col[0] + max(s) > col[1]:
                out.append(('slope-roof', mid, where, 'the slope pokes %d hu through the roof' % (col[0] + max(s) - col[1])))
            if not steep(m, r, c):
                continue
            for side, (dr, dc, i, j, opp) in enumerate(SIDES):
                if not (s[i] == min(s) and s[j] == min(s)):
                    continue                                # not a low edge
                r2, c2 = r + dr, c + dc
                col2 = column(m, r2, c2)
                if col2 is None:
                    continue                                # a drop: not a trap
                low = col[0] + min(s)
                if _blocked(m, tags, r2, c2) or _edge_h(m, r2, c2, opp, False) > low + step:
                    out.append(('slope-trap', mid, where, 'a steep slope slides into a wall on its %s side' % SIDE_WORDS[side]))
                elif steep(m, r2, c2):
                    s2 = slope(m, r2, c2)
                    if s2[SIDES[opp][2]] == min(s2) and s2[SIDES[opp][3]] == min(s2):
                        out.append(('slope-trap', mid, where, 'two steep slopes slide into each other on its %s side' % SIDE_WORDS[side]))


def check_pack(pack, tags=None):
    """the E12 checker over a pack (or a map: check()): a list of (kind, map id, 'col,row', words)"""
    tags = tag_lookup(tags)
    out = [('pack', '', '', p) for p in pack['problems']]
    es = [e for e in pack['maps'] if e['map'] is not None]
    start = pack_map(pack, pack['meta'].get('start', '')) or (es[0] if es else None)
    seed = None
    if start is None or start['map'] is None:
        out.append(('start', pack['meta'].get('start', ''), '', 'no start map'))
    else:
        spots = [(r, c) for r, row in enumerate(start['map']['tags']) for c, t in enumerate(row) if t == '@']
        if not spots:
            out.append(('start', start['id'], '', 'the start map has no @ cell'))
        else:
            seed = (start['id'],) + spots[0]
    for e in es:
        _check_one(e['map'], tags, e['id'], out)
    # place positions: a map's cell c (0-based) is column c + shift of its place's first map
    first = {}
    shift = {}
    for e in es:
        g = first.setdefault(e['place'], e)
        ac, ar = (int(v) for v in e['at'].split(','))
        gc, gr = (int(v) for v in g['at'].split(','))
        shift[e['id']] = (ac - gc, ar - gr)
    byid = {e['id']: e for e in es}

    def cell_of(e, pc, pr):                                 # place position -> this map's 0-based r, c
        return pr - shift[e['id']][1], pc - shift[e['id']][0]

    def node_air(e, r, c):
        """air over the cell's ground (hu), with the decks of the other maps of its place; None = cannot stand"""
        m = e['map']
        col = column(m, r, c)
        if col is None or _blocked(m, tags, r, c):
            return None
        top = e['base'] + col[0]
        air = (col[1] - col[0]) if col[1] is not None else NO_ROOF
        pc, pr = c + shift[e['id']][0], r + shift[e['id']][1]
        for e2 in es:
            if e2 is e or e2['place'] != e['place']:
                continue
            r2, c2 = cell_of(e2, pc, pr)
            col2 = column(e2['map'], r2, c2)
            if col2 is None:
                continue
            lo, hi = e2['base'] + min(0, col2[0]), e2['base'] + col2[0]
            if lo >= top:
                air = min(air, lo - top)
            elif hi > top:
                air = 0
        return air if air >= opt(m, 'head') else None
    seen = set()
    if seed is not None and node_air(byid[seed[0]], seed[1], seed[2]) is not None:
        todo = [seed]
        seen.add(seed)
        while todo:
            mid, r, c = todo.pop()
            e = byid[mid]
            m = e['map']
            nxt = []
            for side, (dr, dc, i, j, opp) in enumerate(SIDES):
                h = e['base'] + _edge_h(m, r, c, side, True)
                pc, pr = c + dc + shift[mid][0], r + dr + shift[mid][1]
                best = None
                for e2 in es:
                    if e2['place'] != e['place']:
                        continue
                    r2, c2 = cell_of(e2, pc, pr)
                    air = node_air(e2, r2, c2) if 0 <= r2 < e2['map']['meta']['rows'] and 0 <= c2 < e2['map']['meta']['cols'] else None
                    if air is None:
                        continue
                    h2 = e2['base'] + _edge_h(e2['map'], r2, c2, opp, False)
                    if h2 <= h + opt(m, 'step') and (air >= OPEN_SKY or h <= h2 + air) and (best is None or h2 > best[0]):
                        best = (h2, (e2['id'], r2, c2))
                if best is not None:
                    nxt.append(best[1])
            for d in pack['doors']:
                if d['from'] == '%s:%d,%d' % (mid, c + 1, r + 1):
                    to = d['to'].split(':')
                    if to[0] in byid and len(to) == 2 and _cr(to[1]):
                        f = _cr(to[1])
                        nxt.append((to[0], f[1] - 1, f[0] - 1))
            for k in m.get('links', []):
                if k['type'] == 'teleport' and k['from'] == '%d,%d' % (c + 1, r + 1):
                    for to in k['to'].split():
                        f = _cr(to)
                        if f and not to.startswith('@'):
                            nxt.append((mid, f[1] - 1, f[0] - 1))
            for n in nxt:
                e2 = byid[n[0]]
                if n not in seen and 0 <= n[1] < e2['map']['meta']['rows'] and 0 <= n[2] < e2['map']['meta']['cols'] \
                        and node_air(e2, n[1], n[2]) is not None:
                    seen.add(n)
                    todo.append(n)
    for d in pack['doors']:
        to = d['to'].split(':')
        if to[0] not in byid:
            continue                                        # the reader already says so
        f = _cr(to[1]) if len(to) == 2 else None
        e2 = byid[to[0]]
        ok = f is not None
        if ok:
            r2, c2 = f[1] - 1, f[0] - 1
            ok = 0 <= r2 < e2['map']['meta']['rows'] and 0 <= c2 < e2['map']['meta']['cols']
        if not ok:
            out.append(('door', to[0], to[1] if len(to) == 2 else '', 'a %s door from %s: outside the map' % (d['type'], d['from'])))
        elif node_air(e2, r2, c2) is None:
            out.append(('door', to[0], to[1], 'a %s door from %s onto a cell nobody can stand on' % (d['type'], d['from'])))
    for e in es:
        lower = [e2 for e2 in es if e2['place'] == e['place'] and e2['base'] < e['base']]
        if not lower:
            continue
        m = e['map']
        for r in range(m['meta']['rows']):
            for c in range(m['meta']['cols']):
                if column(m, r, c) is not None:
                    continue
                if not any(column(m, r + dr, c + dc) is not None for dr, dc, i, j, o in SIDES):
                    continue                                # not beside the deck
                pc, pr = c + shift[e['id']][0], r + shift[e['id']][1]
                if not any(column(e2['map'], *cell_of(e2, pc, pr)) is not None for e2 in lower):
                    out.append(('hole', e['id'], '%d,%d' % (c + 1, r + 1), 'a hole with nothing under it'))
    if seed is not None:                                # a step too high, where it cuts an area off
        for e in es:
            m = e['map']
            for r in range(m['meta']['rows']):
                for c in range(m['meta']['cols']):
                    if (e['id'], r, c) in seen or node_air(e, r, c) is None:
                        continue
                    for dr, dc, i, j, o in SIDES:
                        if (e['id'], r + dr, c + dc) not in seen:
                            continue
                        d = column(m, r, c)[0] - column(m, r + dr, c + dc)[0]
                        if opt(m, 'step') < d <= 2 * opt(m, 'step'):
                            out.append(('step', e['id'], '%d,%d' % (c + 1, r + 1),
                                        'a step of %d hu (step is %d) cuts this off' % (d, opt(m, 'step'))))
                            break
    if seed is not None:
        for e in es:
            m = e['map']
            left = set((r, c) for r in range(m['meta']['rows']) for c in range(m['meta']['cols'])
                       if (e['id'], r, c) not in seen and node_air(e, r, c) is not None)
            for r in range(m['meta']['rows']):
                for c in range(m['meta']['cols']):
                    if (r, c) not in left:
                        continue
                    n, todo = 0, [(r, c)]
                    left.discard((r, c))
                    while todo:
                        a, b = todo.pop()
                        n += 1
                        for dr, dc, i, j, o in SIDES:
                            if (a + dr, b + dc) in left:
                                left.discard((a + dr, b + dc))
                                todo.append((a + dr, b + dc))
                    out.append(('unreachable', e['id'], '%d,%d' % (c + 1, r + 1),
                                '%d cell%s nobody can walk to from the start' % (n, '' if n == 1 else 's')))
    return out


def check(m, tags=None):
    """the E12 checker over one map: a list of (kind, map id, 'col,row', words)"""
    mid = m['meta'].get('name', 'map')
    pack = dict(meta=dict(name=mid, start=mid), maps=[dict(id=mid, file='', place='main', base=0, at='1,1',
                map=upgrade(copy.deepcopy(m)), ox=0.0, oz=0.0)], doors=[], problems=[])
    return check_pack(pack, tags)


def check_text(problems):
    return ''.join('\t'.join(p) + '\n' for p in problems)


# ------------------------------------------------------------------ version 2: the level as line segments
def glyph_edges(rows16):
    """the outline of a glyph's lit bits as merged runs: [(x1, z1, x2, z2)] in pixels 0-16"""
    def lit(z, x):
        return 0 <= z < 16 and 0 <= x < 16 and (rows16[z] >> x & 1) == 1
    out = []
    for k in range(17):                     # boundaries above pixel row k, then left of pixel column k
        start = None
        for x in range(17):
            on = x < 16 and lit(k - 1, x) != lit(k, x)
            if on and start is None:
                start = x
            if not on and start is not None:
                out.append((start, k, x, k))
                start = None
    for k in range(17):
        start = None
        for z in range(17):
            on = z < 16 and lit(z, k - 1) != lit(z, k)
            if on and start is None:
                start = z
            if not on and start is not None:
                out.append((k, start, k, z))
                start = None
    return out


def level_segments(m, tags=None, font=None):
    """the map as line segments 'x1,y1,z1,x2,y2,z2,class': x and z in sixteenths of a cell from the
    map's north-west corner (x east, z south), y in hu (up). Rules: CELLMAP_V2.md section 6.
    Sorted; runs along a row or column are merged. Scale with seg_to_engine()."""
    tags = tags or tag_lookup()
    rows, cols = m['meta']['rows'], m['meta']['cols']
    slab, relief = opt(m, 'slab'), opt(m, 'relief')
    flat = {}                               # (class, y, axis, fixed) -> [(a, b)]
    ups = set()
    C = [[column(m, r, c) for c in range(cols)] for r in range(rows)]
    shape = {}                              # extrude glyph: the cell is flat floor, its glyph a prism
    for r in range(rows):
        for c in range(cols):
            if shaped(m, font, r, c):
                shape[r, c] = C[r][c][0]
                C[r][c] = (1,) + tuple(C[r][c][1:])

    def col_at(r, c):
        return C[r][c] if 0 <= r < rows and 0 <= c < cols else None

    def edge(cls, y, r, c, side):           # one side of cell r,c at height y
        if side == 'n':
            flat.setdefault((cls, y, 'x', r * 16), []).append((c * 16, c * 16 + 16))
        elif side == 's':
            flat.setdefault((cls, y, 'x', r * 16 + 16), []).append((c * 16, c * 16 + 16))
        elif side == 'w':
            flat.setdefault((cls, y, 'z', c * 16), []).append((r * 16, r * 16 + 16))
        else:
            flat.setdefault((cls, y, 'z', c * 16 + 16), []).append((r * 16, r * 16 + 16))

    def base_class(r, c):
        if m['red'][r][c] > 0:
            return 'pit'
        if m['green'][r][c] > 0 and from_flags(m, r, c) & 1:
            return 'green'                  # a green pillar (From Floor)
        return 'wall'

    def corners(r, c):                      # the ground's four corner heights: nw, ne, se, sw (CELLMAP_V3.md 2)
        g = C[r][c][0]
        s = slope(m, r, c) if (r, c) not in shape else None
        return [g + x for x in s] if s else [g, g, g, g]

    # each side's two corner heights, in the order the side runs (west to east, north to south)
    side_corners = {'n': (0, 1), 'e': (1, 2), 's': (3, 2), 'w': (0, 3)}
    facing = {'n': 's', 'e': 'w', 's': 'n', 'w': 'e'}
    sides = (('n', -1, 0), ('e', 0, 1), ('s', 1, 0), ('w', 0, -1))
    for r in range(rows):
        for c in range(cols):
            col = C[r][c]
            if col is None:
                continue
            ground, rb, rt = col[:3]
            water = is_water(m, tags, r, c)
            k4 = corners(r, c)
            for side, dr, dc in sides:
                n = col_at(r + dr, c + dc)
                a, b = (k4[i] for i in side_corners[side])
                same = False
                if n is not None:
                    n4 = corners(r + dr, c + dc)
                    same = (a, b) == tuple(n4[i] for i in side_corners[facing[side]])
                cls = 'floor' if same else base_class(r, c)
                if a == b:
                    edge(cls, a, r, c, side)
                else:                       # a sloped ground edge runs corner to corner
                    x1, z1 = c * 16 + (16 if side == 'e' else 0), r * 16 + (16 if side == 's' else 0)
                    x2, z2 = (x1 + 16, z1) if side in 'ns' else (x1, z1 + 16)
                    ups.add('%d,%d,%d,%d,%d,%d,%s' % (x1, a, z1, x2, b, z2, cls))
                if rb is not None:
                    edge('ceiling', rb, r, c, side)
                    if rt != rb:
                        edge('green', rt, r, c, side)
                for sb, st in blocks_of(col):
                    if not (n is not None and (sb, st) in blocks_of(n)):
                        edge('sky', sb, r, c, side)
                        edge('sky', st, r, c, side)
                if water:
                    f = m['floor'][r][c]
                    nr, nc = r + dr, c + dc
                    if not (n is not None and is_water(m, tags, nr, nc) and m['floor'][nr][nc] == f):
                        edge('water', f, r, c, side)
            if k4[0] + k4[2] != k4[1] + k4[3]:   # a twisted cell: its diagonal, through the highest corner
                hi = k4.index(max(k4))
                if hi in (0, 2):
                    ups.add('%d,%d,%d,%d,%d,%d,floor' % (c * 16, k4[0], r * 16, c * 16 + 16, k4[2], r * 16 + 16))
                else:
                    ups.add('%d,%d,%d,%d,%d,%d,floor' % (c * 16, k4[3], r * 16 + 16, c * 16 + 16, k4[1], r * 16))
            if water:
                f = m['floor'][r][c]
                ups.add('%d,%d,%d,%d,%d,%d,water' % (c * 16, f, r * 16, c * 16 + 16, f, r * 16 + 16))
            if (r, c) in shape:
                y, cls = shape[r, c], base_class(r, c)
                for x1, z1, x2, z2 in glyph_edges(font['glyph'].get(m['design'][r][c], [0] * 16)):
                    if z1 == z2:
                        flat.setdefault((cls, y, 'x', r * 16 + z1), []).append((c * 16 + x1, c * 16 + x2))
                    else:
                        flat.setdefault((cls, y, 'z', c * 16 + x1), []).append((r * 16 + z1, r * 16 + z2))
                    for px, pz in ((x1, z1), (x2, z2)):
                        ups.add('%d,%d,%d,%d,%d,%d,%s' % (c * 16 + px, 1, r * 16 + pz, c * 16 + px, y, r * 16 + pz, cls))
            elif font is not None and has_relief(m, r, c):
                y = ground + relief
                for x1, z1, x2, z2 in glyph_edges(font['glyph'].get(m['design'][r][c], [0] * 16)):
                    if z1 == z2:
                        flat.setdefault(('relief', y, 'x', r * 16 + z1), []).append((c * 16 + x1, c * 16 + x2))
                    else:
                        flat.setdefault(('relief', y, 'z', c * 16 + x1), []).append((r * 16 + z1, r * 16 + z2))
    # uprights: one a corner
    for j in range(rows + 1):
        for i in range(cols + 1):
            cells = [(j - 1, i - 1), (j - 1, i), (j, i - 1), (j, i)]
            around = [col_at(r, c) for r, c in cells]
            if all(a is None for a in around):
                continue
            gs = [corners(r, c)[k] if a is not None else 0 for (r, c), a, k in zip(cells, around, (2, 3, 1, 0))]
            lo, hi = min(gs), max(gs)
            if hi - lo > 1:
                live = [(r, c) for (r, c), a in zip(cells, around) if a is not None]
                cls = 'pit' if any(m['red'][r][c] > 0 for r, c in live) else \
                      'green' if any(base_class(r, c) == 'green' for r, c in live) else 'wall'
                ups.add('%d,%d,%d,%d,%d,%d,%s' % (i * 16, lo, j * 16, i * 16, hi, j * 16, cls))
            roofs = [a for a in around if a is not None and a[1] is not None]
            if roofs:
                lo, hi = min(a[1] for a in roofs), max(a[2] for a in roofs)
                if hi > lo:
                    cls = 'green' if any(a[2] > a[1] for a in roofs) else 'ceiling'
                    ups.add('%d,%d,%d,%d,%d,%d,%s' % (i * 16, lo, j * 16, i * 16, hi, j * 16, cls))
            sbs = [set(blocks_of(a)) if a is not None else set() for a in around]   # slab bottom, top
            for s, t in set().union(*sbs):
                if not all((s, t) in x for x in sbs):     # an upright where a block's side shows
                    ups.add('%d,%d,%d,%d,%d,%d,sky' % (i * 16, s, j * 16, i * 16, t, j * 16))
    out = set(ups)
    for (cls, y, axis, fixed), runs in flat.items():
        runs = sorted(set(runs))
        a, b = runs[0]
        merged = []
        for a2, b2 in runs[1:]:
            if a2 <= b:
                b = max(b, b2)
            else:
                merged.append((a, b))
                a, b = a2, b2
        merged.append((a, b))
        for a, b in merged:
            if axis == 'x':
                out.add('%d,%d,%d,%d,%d,%d,%s' % (a, y, fixed, b, y, fixed, cls))
            else:
                out.add('%d,%d,%d,%d,%d,%d,%s' % (fixed, y, a, fixed, y, b, cls))
    return sorted(out)


def seg_to_engine(m, seg):
    """a level segment in engine units, map centred on 0,0, y up: (x1, y1, z1, x2, y2, z2, class)"""
    f = seg.split(',')
    cell, k = m['meta']['cell'], hu(m)
    def X(v): return (int(v) / 16 - m['meta']['cols'] / 2) * cell
    def Z(v): return (int(v) / 16 - m['meta']['rows'] / 2) * cell
    def Y(v): return (int(v) + opt(m, 'base')) * k
    return X(f[0]), Y(f[1]), Z(f[2]), X(f[3]), Y(f[4]), Z(f[5]), f[6]


def pack_segments(pack, place, tags=None, font=None):
    """every map of one place drawn together: level_segments of each, moved by its ox, oz and the
    pack's base (CELLMAP_V3.md 3, 4). Engine units, y up: (x1, y1, z1, x2, y2, z2, class, map id),
    in the pack's order, each map's lines sorted"""
    out = []
    for e in pack_place(pack, place):
        m = e['map']
        cell, k = m['meta']['cell'], hu(m)
        hc, hr = m['meta']['cols'] / 2, m['meta']['rows'] / 2
        for seg in level_segments(m, tags, font):
            f = seg.split(',')
            out.append(((int(f[0]) / 16 - hc) * cell + e['ox'], (int(f[1]) + e['base']) * k, (int(f[2]) / 16 - hr) * cell + e['oz'],
                        (int(f[3]) / 16 - hc) * cell + e['ox'], (int(f[4]) + e['base']) * k, (int(f[5]) / 16 - hr) * cell + e['oz'],
                        f[6], e['id']))
    return out


def level_boxes(m, tags=None):
    """the solid look (xt3d): one box a column part, engine units, y up, centre + size:
    (x, y, z, width, height, depth, class); class ground / roof / slab / water"""
    tags = tags or tag_lookup()
    k, cell, out = hu(m), m['meta']['cell'], []
    deep = min([0] + [column(m, r, c)[0] for r in range(m['meta']['rows']) for c in range(m['meta']['cols'])
                      if column(m, r, c) is not None]) - 10
    for r in range(m['meta']['rows']):
        for c in range(m['meta']['cols']):
            col = column(m, r, c)
            if col is None:
                continue
            ground, rb, rt = col[:3]
            x, z = cell_x(m, c + 1), cell_z(m, r + 1)
            def box(lo, hi, cls):
                out.append((x, (lo + hi) / 2 * k, z, cell, (hi - lo) * k, cell, cls))
            box(deep, ground, 'ground')
            if rb is not None:
                box(rb, max(rt, rb + 1), 'roof')
            for sb, st in blocks_of(col):
                box(sb, st, 'slab')
            if is_water(m, tags, r, c):
                box(ground, m['floor'][r][c], 'water')
    return out


# ------------------------------------------------------------------ the version 2 sample (the owner, 11 14 2026)
def sample():
    """'a map with a swimming pool, a raised dais, a wizard's tower and some clouds', a maze corner,
    and a screen of glyphs laid flat to walk on: maps/wizard_pool.cellmap"""
    cols, rows = 24, 18
    m = new_map2(cols, rows, name='wizard_pool', cell=76, wallH=62, font='Aquarius')
    def put(c, r, tag=None, design=None, **layers):         # 1-based col, row
        if tag is not None:
            m['tags'][r - 1][c - 1] = tag
            m['design'][r - 1][c - 1] = ord(tag) if design is None else design
        elif design is not None:
            m['design'][r - 1][c - 1] = design
        for k, v in layers.items():
            m[k][r - 1][c - 1] = v
    # the courtyard wall
    for c in range(1, cols + 1):
        for r in range(1, rows + 1):
            if c in (1, cols) or r in (1, rows):
                put(c, r, '#', floor=100)
    # the maze corner, north-west: roofed hallways (ceiling 100), one way out to the yard
    grid = maze(4, 3, 7)
    grid[5] = grid[5][:8] + '0'
    for j, line in enumerate(grid):
        for i, ch in enumerate(line):
            if ch == '1':
                put(1 + i, 1 + j, '#', floor=100)
            else:
                put(1 + i, 1 + j, '~', design=46, floor=1, ceiling=100)
    # the swimming pool, south-west: steps of 20 down to 60; shallow water round the edge, deep in the middle
    for c in range(4, 11):
        for r in range(11, 17):
            ring = min(c - 4, 10 - c, r - 11, 16 - r)
            put(c, r, 'w' if ring == 0 else '}', design=ord('~'), floor=1, red=20 * (ring + 1))
    # the raised dais, south: a ring one step up, a platform two steps up, the goal on top
    for c in range(13, 18):
        for r in range(11, 16):
            ring = min(c - 13, 17 - c, r - 11, 15 - r)
            put(c, r, '.', design=ord('=') if ring == 0 else ord('#'), floor=21 if ring == 0 else 41)
    put(15, 13, 'X', floor=41)
    # the wizard's tower, north-east: walls of green 200 From Floor (455 hu, the map's top), a room
    # under a roof solid From Ceiling (255 up to the top), a door (roof solid from 100 up)
    m['meta']['top'] = 455
    for c in range(19, 23):
        for r in range(3, 7):
            if c in (19, 22) or r in (3, 6):
                put(c, r, '#', floor=255, green=200, **{'from': 1})
            else:
                put(c, r, '.', floor=1, ceiling=255, **{'from': 2})
    put(20, 6, "'", floor=1, ceiling=100, **{'from': 2})
    put(21, 4, 'T', floor=1, ceiling=255, **{'from': 2})    # the wizard's teleporter: up to the clouds
    put(20, 4, '*', floor=1, ceiling=255, **{'from': 2})
    # the clouds, north: green blocks floating at 265 hu (green 10) over the yard; the middle one is
    # where the teleporter lands
    for c, r in ((12, 2), (13, 2), (14, 2), (13, 3), (14, 3), (15, 3), (16, 3), (14, 4), (15, 4), (16, 4), (17, 4), (15, 5), (16, 5)):
        put(c, r, green=10)
    put(10, 9, green=1)
    put(11, 9, green=1)
    # the screen laid flat: glyphs raised in low relief, something to step on
    for j, text in enumerate(('PROMPT &', ' GLAZE  ', 'WALK ME!')):
        for i, ch in enumerate(text):
            if ch != ' ':
                put(11 + i, 6 + j, design=ord(ch))
    for i, code in enumerate((222, 172, 172, 220, 172, 172, 172, 206)):
        put(11 + i, 9, design=code) if i not in (0, 1) else None
    # who starts where
    put(12, 10, '@', design=46)
    put(13, 10, 'N', design=46)
    put(18, 9, 'o', design=46)
    m['links'] = [dict({'from': '21,4', 'type': 'teleport', 'to': '15,4', 'note': 'the wizard sends you up to the clouds'}),
                  dict({'from': '15,13', 'type': 'pad', 'to': '20,6', 'note': 'standing on the dais is noticed at the tower door'})]
    m['objects'] = [dict(id='orb1', kind='ball', at='18,9', facing=0, above=0, props='sides=16'),
                    dict(id='beacon', kind='beacon', at='15,13', facing=0, above=0, props='colour=#FFD040')]
    return autowall(m, full=9)


# ------------------------------------------------------------------ LIB_BIT's maze (same numbers as Bit.Maze)
def maze(cols, rows=None, seed=1):
    rows = rows or cols
    x = abs(int(seed)) % 2147483647 or 1
    w, h = 2 * cols + 1, 2 * rows + 1
    g = [['1'] * (w + 1) for _ in range(h + 1)]            # 1-based like the LiveCode
    seen = {(1, 1)}
    g[2][2] = '0'
    stack = [(1, 1)]
    steps = 0
    while stack and steps < 4 * cols * rows + 10:
        steps += 1
        c, r = stack[-1]
        dirs = [(c + dx, r + dy) for dx, dy in ((0, -1), (1, 0), (0, 1), (-1, 0))
                if 1 <= c + dx <= cols and 1 <= r + dy <= rows and (c + dx, r + dy) not in seen]
        if not dirs:
            stack.pop()
            continue
        x = (x * 16807) % 2147483647
        nx, ny = dirs[x % len(dirs)]
        seen.add((nx, ny))
        g[r + ny][c + nx] = '0'
        g[2 * ny][2 * nx] = '0'
        stack.append((nx, ny))
    return [''.join(g[r][1:w + 1]) for r in range(1, h + 1)]


def example():
    """Amazing Couple's defaults: kRooms 6 (a 13 x 13 grid), kCell 76, kWallH 58, seed 1"""
    grid = maze(6, 6, 1)
    m = new_map(13, 13, name='amazing_couple', cell=76, wallH=58, font='Aquarius')
    for r, line in enumerate(grid):
        for c, ch in enumerate(line):
            wall = ch == '1'
            m['tags'][r][c] = '#' if wall else '.'
            m['design'][r][c] = ord('#') if wall else ord('.')
            m['heights'][r][c] = 9 if wall else 0
    m['tags'][1][1] = '@'                       # PROMPT starts in the first room
    m['tags'][1][2] = 'N' if grid[1][2] == '0' else m['tags'][1][2]     # GLAZE beside
    m['tags'][11][11] = 'X'                     # the gold beacon, far corner
    m['tags'][5][5] = 'o'                       # the ball (Big Ball of Vectors)
    # the owner's example: the first six wall cells of the top row are built from the glyphs C L A U D E
    for i, ch in enumerate('CLAUDE'):
        m['design'][0][1 + i] = ord(ch)
    # a low step and a fence in open rooms, to show heights below a full wall
    for (r, c, t) in ((3, 1, '_'), (9, 9, '=')):
        if grid[r][c] == '0':
            m['tags'][r][c] = t
            m['heights'][r][c] = dict((x[0], x[3]) for x in TAGS)[t]
    return autowall(m)


def show(m):
    print('%s: %d x %d, cell %s, wall %s, font %s' % (m['meta'].get('name'), m['meta'].get('cols'),
          m['meta'].get('rows'), m['meta'].get('cell'), m['meta'].get('wallH'), m['meta'].get('font')))
    names = {t['char']: t['name'] for t in tag_table() if t['char']}
    print('\ntags               design             heights')
    w = m['meta'].get('cols', 13) + 6
    for r, (t, d) in enumerate(zip(m['tags'], m['design'])):
        print(''.join(t).ljust(w) + ''.join(chr(c) if printable(c) else '?' for c in d).ljust(w) +
              ''.join(B36[height1(m, r, c)] for c in range(len(t))))
    used = sorted({c for row in m['tags'] for c in row})
    print('\nlegend: ' + ',  '.join('%s %s' % (c, names.get(c, '?')) for c in used))


def main(argv):
    cmd = argv[1] if len(argv) > 1 else ''
    if cmd == 'tags':
        print('wrote', write_tags())
    elif cmd == 'fonts':
        for f in sorted(os.listdir(os.path.join(ROOT, 'fonts'))):
            if f.endswith('.json'):
                print('wrote', json_to_font(os.path.join(ROOT, 'fonts', f),
                                            os.path.join(ROOT, 'fonts', f[:-5] + '.font.txt')))
    elif cmd == 'example':
        p = os.path.join(ROOT, 'maps', 'amazing_couple.cellmap')
        write_map(example(), p)
        print('wrote', p)
    elif cmd == 'onebit':
        m = read_map(argv[2])
        font = read_font(os.path.join(ROOT, 'fonts', m['meta']['font'] + '.font.txt'))
        for row in onebit_rows(m, font)[::2]:
            print(row[::2].replace('0', ' ').replace('1', '#'))
    elif cmd == 'sample':
        p = os.path.join(ROOT, 'maps', 'wizard_pool.cellmap')
        write_map(sample(), p)
        print('wrote', p)
    elif cmd == 'upgrade':
        write_map(upgrade(read_map(argv[2])), argv[3])
        print('wrote', argv[3])
    elif cmd == 'segments':
        m = upgrade(read_map(argv[2]))
        font = read_font(os.path.join(ROOT, 'fonts', m['meta']['font'] + '.font.txt'))
        print('\n'.join(level_segments(m, tag_lookup(), font)))
    elif cmd == 'heights':
        m = upgrade(read_map(argv[2]))
        for layer in LAYERS2:
            print('[%s]' % layer)
            print('\n'.join(' '.join('%3d' % x for x in row) for row in m[layer]))
    elif cmd == 'show':
        show(read_map(argv[2]))
    elif cmd == 'check':
        same = map_text(read_map(argv[2])) == open(argv[2], encoding='utf-8').read()
        print('round trip:', 'SAME' if same else 'DIFFERENT')
        return 0 if same else 1
    else:
        print(__doc__)
    return 0


if __name__ == '__main__':
    if any(a in ('-h', '--help') for a in sys.argv[1:]):   # A-50: every tool answers --help
        print(__doc__)
        sys.exit(0)
    sys.exit(main(sys.argv))
