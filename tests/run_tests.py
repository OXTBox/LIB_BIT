#!/usr/bin/env python3
"""Run LIB_BIT's tests inside real LiveCode 9.6.3, through LIB_MCP's standalone server.

    python3 tests/run_tests.py

Loads livecode/lib_bit.livecodescript into the standalone with `start using`, evaluates
each expression there and compares with the expected text. Needs ~/projects/LIB_MCP.
"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
LIB = os.path.join(os.path.dirname(HERE), 'livecode', 'lib_bit.livecodescript')
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(HERE)), 'LIB_MCP', 'python'))
from lib_mcp.client import Client, local_to_win

G = '"0110" & return & "1000" & return & "0001"'      # 4 wide, 3 high
TESTS = [
    ('Bit.Blank(3, 2)', '000\n000'),
    ('Bit.Width(%s)' % G, '4'),
    ('Bit.Height(%s)' % G, '3'),
    ('Bit.Count(%s)' % G, '4'),
    ('Bit.Invert(%s)' % G, '1001\n0111\n1110'),
    ('Bit.FromLongString("10010110", 4)', '1001\n0110'),
    ('Bit.Shift(%s, "left")' % G, '1100\n0001\n0010'),
    ('Bit.Shift(%s, "right")' % G, '0011\n0100\n1000'),
    ('Bit.Shift(%s, "up")' % G, '1000\n0001\n0110'),
    ('Bit.Shift(%s, "down")' % G, '0001\n0110\n1000'),
    ('Bit.FlipHorizontal(%s)' % G, '0110\n0001\n1000'),
    ('Bit.FlipVertical(%s)' % G, '0001\n1000\n0110'),
    ('Bit.Rotate(%s, 90)' % G, '010\n001\n001\n100'),
    ('Bit.Rotate(%s, -90)' % G, '001\n100\n100\n010'),
    ('Bit.Rotate(Bit.Rotate(%s, 90), -90) is (%s)' % (G, G), 'true'),
    ('Bit.Pad("11" & return & "11", 4)', '0000\n0110\n0110\n0000'),
    ('Bit.ToPBM(%s)' % G, 'P1\n4 3\n0110\n1000\n0001\n'),
    ('Bit.FromPBM("P1" & return & "# comment" & return & "4 3" & return & "0 1 1 0 1 0 0 0 0 0 0 1")', '0110\n1000\n0001'),
    ('Bit.FromPBM(Bit.ToPBM(%s)) is (%s)' % (G, G), 'true'),
    ('Bit.ToRows(%s)' % G, '6,1,8'),
    ('Bit.FromRows("6,1,8", 4)', '0110\n1000\n0001'),
    # a real BitFontMaker2 glyph row ("97":[...,496,...]): columns 5-9 filled
    ('Bit.FromRows("496", 16)', '0000111110000000'),
    ('Bit.ToRows(Bit.FromRows("0,496,280,256,992", 16))', '0,496,280,256,992'),
    # Bit.Maze: the exact grid is also produced by the Python twin (same Park-Miller numbers)
    ('Bit.Maze(4, 3, 42)', '111111111\n100010001\n111010101\n100010101\n101111101\n100000001\n111111111'),
    ('Bit.Width(Bit.Maze(6, 5, 3)) & "," & Bit.Height(Bit.Maze(6, 5, 3))', '13,11'),
    # a perfect maze: every room open plus one passage fewer than rooms (2*30-1 open cells)
    ('Bit.Count(Bit.Invert(Bit.Maze(6, 5, 3)))', '59'),
    ('Bit.Maze(6, 5, 3) is Bit.Maze(6, 5, 3)', 'true'),
    ('Bit.Maze(6, 5, 3) is Bit.Maze(6, 5, 4)', 'false'),
]


def main():
    c = Client.standalone()
    # a stack stays in memory after "stop using"; delete it so the file is read again
    ok, out = c.run('if there is a stack "LIB_BIT" then delete stack "LIB_BIT"\n'
                    'start using stack "%s"\nput "loaded"' % local_to_win(LIB).replace('\\', '/'), in_server=True)
    if not ok or 'loaded' not in out:
        print('Could not load LIB_BIT:', out)
        return 2
    failed = 0
    for expr, want in TESTS:
        ok, got = c.eval(expr, in_server=True)
        got = got.replace('\r', '')
        good = ok and got == want
        failed += not good
        print('%s  %s' % ('PASS' if good else 'FAIL', expr if good else '%s\n      want %r\n      got  %r' % (expr, want, got)))
    c.run('stop using stack "%s"' % local_to_win(LIB).replace('\\', '/'), in_server=True)
    print('\n%d of %d passed' % (len(TESTS) - failed, len(TESTS)))
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
