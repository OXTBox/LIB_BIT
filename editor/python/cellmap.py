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
            out.append(dict(code=code, char=t[0], name=t[1], solid=t[2], height=t[3], group=t[4]))
        else:
            out.append(dict(code=code, char=chr(code) if code >= 161 else '', name='custom %d' % code,
                            solid=0, height=0, group='custom'))
    for i, t in enumerate(out):
        t['colour'] = colour(i)
    return out


def write_tags(path=None):
    path = path or os.path.join(ROOT, 'data', 'tags_default.txt')
    lines = ['# cellmap tag table: code, char (empty = not printable), name, colour, solid, height (0-35), group',
             '# Colours are data, not code: change any; regenerate with "cellmap.py tags" (R G B Y M C, a new shade a round).']
    for t in tag_table():
        lines.append('\t'.join(str(t[k]) for k in ('code', 'char', 'name', 'colour', 'solid', 'height', 'group')))
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
                    font='Base_001', tags='tags_default', version=1)


def new_map(cols=13, rows=13, **meta):
    m = dict(meta=dict(DEFAULT_META, cols=cols, rows=rows, **meta))
    m['design'] = [[ord('.')] * cols for _ in range(rows)]
    m['tags'] = [['.'] * cols for _ in range(rows)]
    m['heights'] = [[0] * cols for _ in range(rows)]
    m['tagdefs'] = {}
    return m


def printable(code):
    return 32 <= code <= 126 or 161 <= code <= 255


def write_map(m, path):
    out = ['# cellmap 1 - LIB_BIT/editor (format: editor/README.md)', '[map]']
    out += ['%s\t%s' % (k, v) for k, v in m['meta'].items()]
    if all(printable(c) for row in m['design'] for c in row):
        out.append('[design]')
        out += [''.join(chr(c) for c in row) for row in m['design']]
    else:
        out.append('[design hex]')
        out += [' '.join('%02X' % c for c in row) for row in m['design']]
    out.append('[tags]')
    out += [''.join(row) for row in m['tags']]
    out.append('[heights]')
    out += [''.join(B36[h] for h in row) for row in m['heights']]
    if m.get('tagdefs'):
        out.append('[tagdefs]')
        for ch, t in sorted(m['tagdefs'].items()):
            out.append('\t'.join([ch, t['name'], t['colour'], str(t['solid']), str(t['height'])]))
    open(path, 'w', encoding='utf-8', newline='\n').write('\n'.join(out) + '\n')


def read_map(path):
    m = dict(meta={}, design=[], tags=[], heights=[], tagdefs={})
    sec = None
    for line in open(path, encoding='utf-8'):
        line = line.rstrip('\n')
        if line.startswith('#') and sec in (None, 'map'):       # rows and tag defs may start with '#'
            continue
        if line.startswith('[') and line.endswith(']') and line[1:-1] in ('map', 'design', 'design hex', 'tags', 'heights', 'tagdefs'):
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
        elif sec == 'tagdefs' and line:
            f = line.split('\t')
            m['tagdefs'][f[0]] = dict(name=f[1], colour=f[2], solid=int(f[3]), height=int(f[4]))
    cols = m['meta'].get('cols', 0)
    for layer, pad in (('design', 32), ('tags', ' '), ('heights', 0)):        # short rows (trimmed spaces) padded
        m[layer] = [row + [pad] * (cols - len(row)) for row in m[layer]]
    return m


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
    m = new_map(13, 13, name='amazing_couple', cell=76, wallH=58)
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
    return m


def show(m):
    print('%s: %d x %d, cell %s, wall %s, font %s' % (m['meta'].get('name'), m['meta'].get('cols'),
          m['meta'].get('rows'), m['meta'].get('cell'), m['meta'].get('wallH'), m['meta'].get('font')))
    names = {t['char']: t['name'] for t in tag_table() if t['char']}
    print('\ntags               design             heights')
    for t, d, h in zip(m['tags'], m['design'], m['heights']):
        print(''.join(t).ljust(19) + ''.join(chr(c) if printable(c) else '?' for c in d).ljust(19) + ''.join(B36[x] for x in h))
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
    elif cmd == 'show':
        show(read_map(argv[2]))
    elif cmd == 'check':
        a = read_map(argv[2])
        tmp = argv[2] + '.check'
        write_map(a, tmp)
        same = open(tmp, encoding='utf-8').read() == open(argv[2], encoding='utf-8').read()
        os.remove(tmp)
        print('round trip:', 'SAME' if same else 'DIFFERENT')
        return 0 if same else 1
    else:
        print(__doc__)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
