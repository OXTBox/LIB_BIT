#!/usr/bin/env python3
"""The E12 checker (Python side): python3 -I tests/py_check_test.py
Makes tests/_check/ (a map with one of each problem, a pack of three maps), checks that each
problem is found, and writes tests/_py_check.txt: the checker's lines for those and for every
map in maps/, which tests/lc_check_test.txt compares with the xTalk library's answers."""
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

work = os.path.join(HERE, '_check')
os.makedirs(work, exist_ok=True)
maps = os.path.join(HERE, '..', 'maps')


def room(cols, rows, name, start=None):
    """walls round the edge (# at 100 hu), floor 1 inside"""
    m = cm.new_map2(cols, rows, name=name)
    for r in range(rows):
        for c in range(cols):
            if r in (0, rows - 1) or c in (0, cols - 1):
                put(m, c + 1, r + 1, '#', 100)
    if start:
        put(m, start[0], start[1], '@')
    return m


def put(m, col, row, tag=None, floor=None, **layers):
    if tag is not None:
        m['tags'][row - 1][col - 1] = tag
    if floor is not None:
        m['floor'][row - 1][col - 1] = floor
    for k, v in layers.items():
        m[k][row - 1][col - 1] = v


# one map, one of each problem
bad = room(10, 8, 'bad', (2, 2))
cm.set_slope(bad, 1, 2, [10, 10, 10, 10])                   # 3,2 all four corners lifted
put(bad, 4, 2, ceiling=90)
cm.set_slope(bad, 1, 3, [0, 0, 100, 100])                   # 4,2 pokes 11 through its roof at 90 (steep, low edge north: floor, no trap)
cm.set_slope(bad, 1, 5, [90, 90, 0, 0])                     # 6,2 steep, low edge south ...
put(bad, 6, 3, '#', 100)                                    # ... into a wall: a trap
cm.set_slope(bad, 4, 2, [90, 0, 0, 90])                     # 3,5 low edge east ...
cm.set_slope(bad, 4, 3, [0, 90, 90, 0])                     # 4,5 low edge west: two slides face each other
put(bad, 9, 7, ' ', 0)
cm.set_slope(bad, 6, 8, [0, 40, 40, 0])                     # 9,7 a slope on an empty cell
cm.set_slope(bad, 5, 6, [90, 90, 0, 0])                     # 7,6 steep, low edge south onto plain floor: no trap
put(bad, 9, 2, None, 46)                                    # 9,2 a plateau 45 up: cut off by its step
for c, r in ((8, 4), (9, 3), (9, 5), (8, 3), (8, 5)):
    put(bad, c, r, '#', 100)
bad['links'] = [dict({'from': '5,4', 'type': 'teleport', 'to': '9,4', 'note': 'into the closed pocket'}),
                dict({'from': '5,6', 'type': 'pad', 'to': '20,20 @nobody', 'note': 'two bad targets'}),
                dict({'from': '30,1', 'type': 'switch', 'to': '5,5', 'note': 'from outside'})]
cm.write_map(bad, os.path.join(work, 'bad.cellmap'))
bad = cm.read_map(os.path.join(work, 'bad.cellmap'))
got = cm.check(bad)
kinds = [p[0] for p in got]
check('bad: all four corners lifted at 3,2', ('slope-all', 'bad', '3,2') in [p[:3] for p in got])
check('bad: the slope pokes through the roof at 4,2', ('slope-roof', 'bad', '4,2') in [p[:3] for p in got])
check('bad: a steep slope into a wall at 6,2', ('slope-trap', 'bad', '6,2') in [p[:3] for p in got])
check('bad: two slides face each other (3,5 and 4,5)',
      [p[2] for p in got if p[0] == 'slope-trap' and 'each other' in p[3]], ['3,5', '4,5'])
check('bad: a slope on an empty cell at 9,7', ('slope-empty', 'bad', '9,7') in [p[:3] for p in got])
check('bad: three bad link ends', [p[2] for p in got if p[0] == 'link'], ['5,6', '5,6', '30,1'])
check('bad: the 45 hu step cuts 9,2 off', ('step', 'bad', '9,2') in [p[:3] for p in got])
check('bad: 9,2 unreachable, one cell', [p[2:] for p in got if p[0] == 'unreachable'],
      [('9,2', '1 cell nobody can walk to from the start')])
check('bad: the pocket at 9,4 is reached by the teleport link', ('unreachable', 'bad', '9,4') not in [p[:3] for p in got])
check('bad: 4,2 against the border wall is a trap too (north)', ('slope-trap', 'bad', '4,2') in [p[:3] for p in got])
check('bad: no trap where the low edge meets plain floor (7,6)', ('slope-trap', 'bad', '7,6') not in [p[:3] for p in got])

nostart = room(5, 5, 'nostart')
check('a map with no @ says so', cm.check(nostart), [('start', 'nostart', '', 'the start map has no @ cell')])
check('...and checking does not change the map', cm.version(nostart), 2)

# a pack: low (the start), high stacked 120 over it and one column wider, odd with another wallH
low = room(5, 5, 'low', (2, 2))
high = room(6, 5, 'high')
for r in range(1, 6):
    put(high, 6, r, '.', 1)                                 # the deck goes one column past the low room
put(high, 6, 3, ' ', 0)                                     # a hole with nothing under it
put(high, 3, 3, ' ', 0)                                     # a hole over the low room: fine
put(high, 2, 2, '#', 100)
odd = room(3, 3, 'odd', None)
odd['meta']['wallH'] = 70
for name, m in (('low', low), ('high', high), ('odd', odd)):
    cm.write_map(m, os.path.join(work, name + '.cellmap'))
open(os.path.join(work, 'stack.cellpack'), 'w', newline='\n').write(
    '[pack]\nname\tstack\nstart\tlow\n[maps]\n'
    'low\tlow.cellmap\tmain\t0\t1,1\nhigh\thigh.cellmap\tmain\t120\t1,1\nodd\todd.cellmap\tmain\t0\t9,9\n'
    '[doors]\nlow:4,4\tladder\thigh:4,4\tup\nlow:3,2\tladder\thigh:2,2\tonto the wall\n'
    'low:2,3\tlift\thigh:9,9\toff the map\nlow:2,4\tdoor\tnowhere:1,1\tno such map\n')
pack = cm.read_pack(os.path.join(work, 'stack.cellpack'))
got = cm.check_pack(pack)
check('pack: the reader\'s problems come first', [p[0] for p in got[:2]], ['pack', 'pack'])
check('pack: a door onto a wall', ('door', 'high', '2,2') in [p[:3] for p in got])
check('pack: a door off the map', ('door', 'high', '9,9') in [p[:3] for p in got])
check('pack: the hole with nothing under it, not the one over the room',
      [p[2] for p in got if p[0] == 'hole'], ['6,3'])
check('pack: the deck is reached up the ladder (no high cell unreachable)',
      [p for p in got if p[0] == 'unreachable' and p[1] == 'high'], [])
check('pack: the odd map is somewhere nobody walks to', [p[1:3] for p in got if p[0] == 'unreachable'], [('odd', '2,2')])

two = cm.check_pack(cm.read_pack(os.path.join(maps, 'two_rooms', 'two_rooms.cellpack')))
check('two_rooms: no problems (stairs, ramp and ladder all reach)', two, [])
couple = cm.check(cm.read_map(os.path.join(maps, 'amazing_couple.cellmap')))
check('amazing_couple: the 36 cells behind the gate at 10,10', [p[:3] for p in couple], [('unreachable', 'amazing_couple', '4,2')])

# the lines the xTalk side must give, file by file
out = []
real = sorted(os.path.join(d, f) for d, _, fs in os.walk(maps) for f in fs if f.endswith('.cellmap'))
for p in [os.path.join(work, 'bad.cellmap'), os.path.join(work, 'nostart.cellmap')] + real:
    if p.endswith('nostart.cellmap'):
        cm.write_map(nostart, p)
    out.append('== ' + os.path.relpath(p, os.path.join(HERE, '..')).replace(os.sep, '/'))
    out.append(cm.check_text(cm.check(cm.read_map(p))).rstrip('\n'))
for p in [os.path.join(work, 'stack.cellpack'), os.path.join(maps, 'two_rooms', 'two_rooms.cellpack')]:
    out.append('== ' + os.path.relpath(p, os.path.join(HERE, '..')).replace(os.sep, '/'))
    out.append(cm.check_text(cm.check_pack(cm.read_pack(p))).rstrip('\n'))
open(os.path.join(HERE, '_py_check.txt'), 'w', newline='\n').write('\n'.join(x for x in out if x) + '\n')
print('ALL OK' if ok else 'SOMETHING FAILED')
sys.exit(0 if ok else 1)
