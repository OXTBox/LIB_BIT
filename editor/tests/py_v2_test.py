#!/usr/bin/env python3
"""cellmap v2 tests (Python side): python3 -I tests/py_v2_test.py
Round trips, v1 -> v2, levels, walking the sample map. Writes tests/_py_segments.txt and
tests/_py_walk.txt, which tests/lc_v2_test.txt compares with LiveCode's answers."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'python'))
import cellmap as cm

ok = True
def check(name, got, want=True):
    global ok
    good = got == want
    ok = ok and good
    print(('ok   ' if good else 'FAIL ') + name + ('' if good else '   got %r want %r' % (got, want)))

maps = os.path.join(HERE, '..', 'maps')
tags = cm.tag_lookup()
font = cm.read_font(os.path.join(HERE, '..', 'fonts', 'Aquarius.font.txt'))
for name in ('amazing_couple', 'wizard_pool'):
    p = os.path.join(maps, name + '.cellmap')
    check(name + ' round trip', cm.map_text(cm.read_map(p)) == open(p, encoding='utf-8').read())
check('sample is what the generator makes', cm.map_text(cm.sample()) == open(os.path.join(maps, 'wizard_pool.cellmap'), encoding='utf-8').read())
v1 = cm.read_map(os.path.join(maps, 'amazing_couple.cellmap'))
check('v1 stays v1', cm.version(v1), 1)
old = [[cm.height1(v1, r, c) for c in range(13)] for r in range(13)]
v2 = cm.upgrade(cm.read_map(os.path.join(maps, 'amazing_couple.cellmap')))
check('upgrade: version 2', cm.version(v2), 2)
check('upgrade: wall 9 -> 100, floor 0 -> 1, step 1 -> 11, fence 3 -> 33',
      (v2['floor'][0][0], v2['floor'][1][1], v2['floor'][3][1], v2['floor'][9][9]), (100, 1, 11, 33))
check('upgrade: old heights read back the same', [[cm.height1(v2, r, c) for c in range(13)] for r in range(13)] == old)
tmp = os.path.join(HERE, '_py_upgraded.cellmap')
cm.write_map(v2, tmp)
check('upgraded file round trip', cm.map_text(cm.read_map(tmp)) == open(tmp, encoding='utf-8').read())
check('h1 <-> floor for 0..23', [cm.floor_to_h1(cm.h1_to_floor(h)) for h in range(24)], list(range(24)))

m = cm.read_map(os.path.join(maps, 'wizard_pool.cellmap'))
check('links and objects read', (len(m['links']), m['links'][0]['type'], m['objects'][0]['kind']), (2, 'teleport', 'ball'))
check('levels: yard', cm.levels(m, 9, 11), [(1, cm.NO_ROOF)])
check('levels: pool middle (bottom 60 under the floor)', cm.levels(m, 13, 6), [(-59, cm.NO_ROOF)])
check('levels: maze hallway (roof at 100, roof top walkable)', cm.levels(m, 1, 1), [(1, 99), (100, cm.NO_ROOF)])
check('levels: tower wall 455', cm.levels(m, 2, 18), [(455, cm.NO_ROOF)])
check('levels: tower room', cm.levels(m, 4, 19), [(1, 254), (455, cm.NO_ROOF)])
check('levels: under a cloud', cm.levels(m, 3, 14), [(1, 220), (231, cm.NO_ROOF)])

k = cm.hu(m)
def go(x, z, y, dx, dz, n):
    e = ''
    for _ in range(n):
        x, z, y, e = cm.walk(m, tags, font, x, z, y, dx, dz)
    return x, z, y, e
walks = []
def run(name, col, row, dx, dz, n, y=None):
    x, z = cm.cell_x(m, col), cm.cell_z(m, row)
    y = cm.ground_at(m, tags, font, x, z) if y is None else y
    x, z, y, e = go(x, z, y, dx, dz, n)
    c, r = cm.cell_at(m, x, z)
    walks.append('%s|%d,%d|%.2f|%s' % (name, c, r, y / k, e))
    return c, r, round(y / k), e
check('walk: start west into the pool, down the steps to the bottom', run('pool', 12, 13, -4, 0, 100, y=1 * k), (7, 13, -59, 'swim'))
check('walk: out of the pool again (steps of 20 are under the 30 limit)', run('poolout', 7, 13, 4, 0, 100, y=-59 * k)[:3], (12, 13, 1))
check('walk: onto the dais: ring 21 then top 41 (+6: standing on the X glyph), the goal', run('dais', 12, 13, 4, 0, 57, y=1 * k), (15, 13, 47, 'goal'))
check('walk: the yard wall stops you', run('wall', 22, 10, 4, 0, 60, y=1 * k)[:3], (23, 10, 1))
check('walk: the tower wall stops you, the door lets you in', (run('towerwall', 21, 9, 0, -4, 80, y=1 * k)[1], run('door', 20, 9, 0, -4, 80, y=1 * k)[:2]), (7, (20, 5)))
check('walk: on the cloud, then off its edge and down', (run('cloud', 15, 4, 0, 0, 1, y=231 * k)[2], run('cloudoff', 15, 4, 0, 4, 40, y=231 * k)[2]), (231, 1))
check('walk: the maze hallway, roofed, out to the yard', run('maze', 2, 6, 4, 0, 200, y=1 * k)[1:3], (6, 1))
gx = cm.cell_x(m, 11) + (5.5 - 8) / 16 * 76
check('relief: the P of PROMPT is 6 hu proud where its bits are lit', (round(cm.ground_at(m, tags, font, gx, cm.cell_z(m, 6) + (1.5 - 8) / 16 * 76) / k),
      round(cm.ground_at(m, tags, font, cm.cell_x(m, 11) - 37, cm.cell_z(m, 6) - 37) / k)), (7, 1))

segs = cm.level_segments(m, tags, font)
open(os.path.join(HERE, '_py_segments.txt'), 'w', newline='\n').write('\n'.join(segs) + '\n')
open(os.path.join(HERE, '_py_walk.txt'), 'w', newline='\n').write('\n'.join(walks) + '\n')

# extrude glyph (the owner, 11 15 2026): the glyph stands as the solid, the rest of the cell is floor
import copy
g = copy.deepcopy(m)
g['meta']['extrude'] = 'glyph'
check('extrude glyph: off by default, a full wall cell is not shaped', cm.shaped(m, font, 0, 0), False)
check('extrude glyph: a wall cell with a glyph is shaped; floor and blank cells are not',
      (cm.shaped(g, font, 0, 1), cm.shaped(g, font, 1, 1), cm.shaped(g, font, 11, 13)), (True, False, True))
# cell col 2,row 1 is the wall piece 172 (a line across the middle): stand on the lit bits, floor beside them
rows172 = font['glyph'][g['design'][0][1]]
litz = [z for z in range(16) if rows172[z] >> 8 & 1]
darkz = [z for z in range(16) if not rows172[z] >> 8 & 1]
def gy(mm, z):
    v = cm.ground_at(mm, tags, font, cm.cell_x(g, 2) + 0.5 / 16 * 76, cm.cell_z(g, 1) + (z + 0.5 - 8) / 16 * 76)
    return None if v is None else round(v / k)
check('extrude glyph: on a lit bit you stand at the wall height; beside it on the floor (a block tag blocks only the glyph)',
      (gy(g, litz[0]), gy(g, darkz[0]), gy(m, darkz[0])), (None, 1, None))
gs = copy.deepcopy(g)
gs['tags'][0][1] = '.'
check('extrude glyph: the same glyph on a walkable tag: its top is the cell height', (gy(gs, litz[0]), gy(gs, darkz[0])), (100, 1))
m = g
gwalks, walks_keep = [], walks
walks = gwalks
run('gwall', 22, 10, 4, 0, 60, y=1 * k)
run('gmaze', 2, 6, 4, 0, 200, y=1 * k)
run('gnorth', 12, 8, 0, -4, 200, y=1 * k)
walks = walks_keep
gsegs = cm.level_segments(g, tags, font)
check('extrude glyph: the level changes, the default does not', (gsegs != segs, cm.level_segments(cm.read_map(os.path.join(maps, 'wizard_pool.cellmap')), tags, font) == segs), (True, True))
ups = [q for q in gsegs if q.split(',')[0] == q.split(',')[3] and q.split(',')[2] == q.split(',')[5] and int(q.split(',')[0]) % 16]
check('extrude glyph: uprights stand inside cells (under glyph corners)', len(ups) > 100)
open(os.path.join(HERE, '_py_segments_glyph.txt'), 'w', newline='\n').write('\n'.join(gsegs) + '\n')
open(os.path.join(HERE, '_py_walk_glyph.txt'), 'w', newline='\n').write('\n'.join(gwalks) + '\n')
print('extrude glyph segments:', len(gsegs), ' walks:', ' / '.join(gwalks))

count = {}
for s in segs:
    count[s.split(',')[6]] = count.get(s.split(',')[6], 0) + 1
print('segments:', len(segs), ' '.join('%s %d' % kv for kv in sorted(count.items())))
check('every class is drawn', sorted(count), ['ceiling', 'floor', 'green', 'pit', 'relief', 'sky', 'wall', 'water'])
check('boxes: one ground a cell + roofs, slabs, water', len(cm.level_boxes(m, tags)) > 24 * 18)
print('ALL OK' if ok else 'SOME FAILED')
sys.exit(0 if ok else 1)
