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
"""
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
LAYERS2 = ['floor', 'ceiling', 'red', 'green', 'blue']
SECTIONS = ['map', 'design', 'design hex', 'tags', 'heights', 'tagdefs'] + LAYERS2 + ['links', 'objects', 'stack']
V2_DEFAULTS = dict(base=0, step=30, head=83, relief=6, slab=10)


def version(m):
    return int(m['meta'].get('version', 1))


def map_text(m):
    v = version(m)
    out = ['# cellmap %d - LIB_BIT/editor (format: editor/%s)' % (v, 'CELLMAP_V2.md' if v >= 2 else 'README.md'), '[map]']
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
            if layer in ('red', 'green', 'blue') and not any(x for row in m[layer] for x in row):
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
    if m.get('tagdefs'):
        out.append('[tagdefs]')
        for ch, t in sorted(m['tagdefs'].items()):
            out.append('\t'.join([ch, t['name'], t['colour'], str(t['solid']), str(t['height']), t.get('effect', 'none')]))
    return '\n'.join(out) + '\n'


def write_map(m, path):
    open(path, 'w', encoding='utf-8', newline='\n').write(map_text(m))


def read_map(path):
    """reads version 1 and version 2 files; a version 1 map stays version 1 (see upgrade)"""
    m = dict(meta={}, design=[], tags=[], heights=[], tagdefs={}, links=[], objects=[], stack=[])
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


def column(m, r, c):
    """a cell's column in hu, or None for empty space / outside:
    ground, roof bottom, roof top (None, None with no roof), slab bottom, slab top (None, None with no slab)"""
    if not (0 <= r < m['meta']['rows'] and 0 <= c < m['meta']['cols']):
        return None
    f, cl, rd, g, b = (m[k][r][c] for k in LAYERS2)
    if f <= 0:
        return None
    ground = f - rd + (g if cl == 0 else 0)
    rb, rt = (cl, cl + g) if cl > 0 else (None, None)
    top = rt if cl > 0 else ground
    sb, st = (top + b, top + b + opt(m, 'slab')) if b > 0 else (None, None)
    return ground, rb, rt, sb, st


NO_ROOF = 9999


def levels(m, r, c):
    """where an actor can stand in a cell: [(top, air above)] in hu, lowest first"""
    col = column(m, r, c)
    if col is None:
        return []
    ground, rb, rt, sb, st = col
    out = []
    if rb is None:
        out.append((ground, (sb - ground) if sb is not None else NO_ROOF))
    else:
        if rb > ground:
            out.append((ground, rb - ground))
        out.append((rt, (sb - rt) if sb is not None else NO_ROOF))
    if sb is not None:
        out.append((st, NO_ROOF))
    return out


def has_relief(m, r, c):
    col = column(m, r, c)
    if col is None or opt(m, 'relief') <= 0 or m['design'][r][c] in (32, 46):
        return False
    return m['red'][r][c] == 0 and col[0] < 100 and (col[1] is None or col[1] > col[0])


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


def stand_at(m, tags, font, x, z, y):
    """the height (engine units) an actor now at height y would stand at on point x,z; None = cannot.
    Blocked by: outside, empty space, a tag whose effect is block or locked, a rise over `step`,
    less than `head` of air."""
    import math
    col, row = cell_at(m, x, z)
    r, c = row - 1, col - 1
    lv = levels(m, r, c)
    if not lv or tag_info(m, tags, m['tags'][r][c], 'effect') in ('block', 'locked'):
        return None
    yh = y / hu(m) - opt(m, 'base')
    best = None
    for i, (top, air) in enumerate(lv):
        if i == 0 and font is not None and has_relief(m, r, c):
            px = min(15, int((x / m['meta']['cell'] + m['meta']['cols'] / 2 - c) * 16))
            pz = min(15, int((z / m['meta']['cell'] + m['meta']['rows'] / 2 - r) * 16))
            if font['glyph'].get(m['design'][r][c], [0] * 16)[pz] >> px & 1:
                top += opt(m, 'relief')
                air -= opt(m, 'relief')
        if top <= yh + opt(m, 'step') + 1e-6 and air >= opt(m, 'head'):
            best = top
    return None if best is None else (best + opt(m, 'base')) * hu(m)


def ground_at(m, tags, font, x, z, y=1e9):
    """the highest standing height at x,z at or below y (engine units); None over empty space"""
    return stand_at(m, tags, font, x, z, y)


def walk(m, tags, font, x, z, y, dx, dz, radius=12):
    """move an actor (a circle) by dx,dz, sliding along what blocks it: (x, z, y, effect of the cell it is in)"""
    def fits(nx, nz):
        for ax in (-radius, radius):
            for az in (-radius, radius):
                if stand_at(m, tags, font, nx + ax, nz + az, y) is None:
                    return None
        return stand_at(m, tags, font, nx, nz, y)
    for tx, tz in ((dx, dz), (dx, 0), (0, dz)):
        ny = fits(x + tx, z + tz)
        if ny is not None and (tx or tz):
            x, z, y = x + tx, z + tz, ny
            break
    col, row = cell_at(m, x, z)
    return x, z, y, tag_info(m, tags, m['tags'][row - 1][col - 1], 'effect')


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
        if m['green'][r][c] > 0 and m['ceiling'][r][c] == 0:
            return 'green'
        return 'wall'

    sides = (('n', -1, 0), ('e', 0, 1), ('s', 1, 0), ('w', 0, -1))
    for r in range(rows):
        for c in range(cols):
            col = C[r][c]
            if col is None:
                continue
            ground, rb, rt, sb, st = col
            water = is_water(m, tags, r, c)
            for side, dr, dc in sides:
                n = col_at(r + dr, c + dc)
                edge('floor' if n is not None and n[0] == ground else base_class(r, c), ground, r, c, side)
                if rb is not None:
                    edge('ceiling', rb, r, c, side)
                    if rt != rb:
                        edge('green', rt, r, c, side)
                if sb is not None and not (n is not None and n[3] == sb):
                    edge('sky', sb, r, c, side)
                    edge('sky', st, r, c, side)
                if water:
                    f = m['floor'][r][c]
                    nr, nc = r + dr, c + dc
                    if not (n is not None and is_water(m, tags, nr, nc) and m['floor'][nr][nc] == f):
                        edge('water', f, r, c, side)
            if water:
                f = m['floor'][r][c]
                ups.add('%d,%d,%d,%d,%d,%d,water' % (c * 16, f, r * 16, c * 16 + 16, f, r * 16 + 16))
            if font is not None and has_relief(m, r, c):
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
            gs = [a[0] if a is not None else 0 for a in around]
            lo, hi = min(gs), max(gs)
            if hi - lo > 1:
                live = [(r, c) for (r, c), a in zip(cells, around) if a is not None]
                cls = 'pit' if any(m['red'][r][c] > 0 for r, c in live) else \
                      'green' if any(m['green'][r][c] > 0 and m['ceiling'][r][c] == 0 for r, c in live) else 'wall'
                ups.add('%d,%d,%d,%d,%d,%d,%s' % (i * 16, lo, j * 16, i * 16, hi, j * 16, cls))
            roofs = [a for a in around if a is not None and a[1] is not None]
            if roofs:
                lo, hi = min(a[1] for a in roofs), max(a[2] for a in roofs)
                if hi > lo:
                    cls = 'green' if any(a[2] > a[1] for a in roofs) else 'ceiling'
                    ups.add('%d,%d,%d,%d,%d,%d,%s' % (i * 16, lo, j * 16, i * 16, hi, j * 16, cls))
            sbs = [a[3] if a is not None else None for a in around]
            if len(set(sbs)) > 1:
                for s in sorted(set(x for x in sbs if x is not None)):
                    ups.add('%d,%d,%d,%d,%d,%d,sky' % (i * 16, s, j * 16, i * 16, s + slab, j * 16))
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
            ground, rb, rt, sb, st = col
            x, z = cell_x(m, c + 1), cell_z(m, r + 1)
            def box(lo, hi, cls):
                out.append((x, (lo + hi) / 2 * k, z, cell, (hi - lo) * k, cell, cls))
            box(deep, ground, 'ground')
            if rb is not None:
                box(rb, max(rt, rb + 1), 'roof')
            if sb is not None:
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
    # the wizard's tower, north-east: walls 255 + green 200 (455 hu), a room under a thick roof, a door
    for c in range(19, 23):
        for r in range(3, 7):
            if c in (19, 22) or r in (3, 6):
                put(c, r, '#', floor=255, green=200)
            else:
                put(c, r, '.', floor=1, ceiling=255, green=200)
    put(20, 6, "'", floor=1, ceiling=100, green=355)
    put(21, 4, 'T', floor=1, ceiling=255, green=200)        # the wizard's teleporter: up to the clouds
    put(20, 4, '*', floor=1, ceiling=255, green=200)
    # the clouds, north: slabs floating 220 hu over the yard; the middle one is where the teleporter lands
    for c, r in ((12, 2), (13, 2), (14, 2), (13, 3), (14, 3), (15, 3), (16, 3), (14, 4), (15, 4), (16, 4), (17, 4), (15, 5), (16, 5)):
        put(c, r, blue=220)
    put(10, 9, blue=180)
    put(11, 9, blue=180)
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
    sys.exit(main(sys.argv))
