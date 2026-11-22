#!/usr/bin/env python3
"""Tests for livecode/lib_lean.livecodescript (the Lean style), inside real LiveCode 9.6.3 through
LIB_MCP's standalone server.

    python3 -I tests/lean_tests.py

Lean.Walls needs the engine's Mesh calls: a tiny stand-in stack (LeanFakeMesh) gives them here,
counting points and lines, so the test can see how many points were shared.
"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
LIB = os.path.join(os.path.dirname(HERE), 'livecode', 'lib_lean.livecodescript')
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(HERE)), 'LIB_MCP', 'python'))
from lib_mcp.client import Client, local_to_win

FAKE = r'''
function Mesh.New
   local tM
   put 0 into tM["n"]
   put 0 into tM["lines"]
   return tM
end Mesh.New
on Mesh.AddVertex @pMesh, pX, pY, pZ
   add 1 to pMesh["n"]
   put pX & comma & pY & comma & pZ into pMesh["v"][pMesh["n"]]
   return pMesh["n"]
end Mesh.AddVertex
on Mesh.AddLine @pMesh, pA, pB
   add 1 to pMesh["lines"]
   put pA & comma & pB into pMesh["l"][pMesh["lines"]]
end Mesh.AddLine
function T.Key pArr, pKey
   return pArr[pKey]
end T.Key
function T.Point pMesh, pN
   return pMesh["v"][pN]
end T.Point
'''

# DotMazeLean's maze (LIB_GAMES/Vibecode3D_Games/DotMaze/DotMazeLean_map.txt)
MAZE = ["###################", "#........#........#", "#.##.###.#.###.##.#", "#.................#",
        "#.##.#.#####.#.##.#", "#....#...#...#....#", "####.###   ###.####", "#....#...#...#....#",
        "#.##.#.#####.#.##.#", "#.................#", "#.##.###.#.###.##.#", "#........#........#",
        "###################"]


def lc_text(lines):
    return ' & return & '.join('"%s"' % l for l in lines)


def py_runs(grid):
    """the number of straight outline runs (DotMazeLean's own count: one layer)"""
    rows, cols = len(grid), max(len(l) for l in grid)
    def solid(c, r):
        return 1 <= r <= rows and 1 <= c <= len(grid[r - 1]) and grid[r - 1][c - 1] == '#'
    n = 0
    for j in range(0, rows + 1):
        on_before = False
        for i in range(1, cols + 1):
            on = solid(i, j) != solid(i, j + 1)
            n += on and not on_before
            on_before = on
    for i in range(0, cols + 1):
        on_before = False
        for j in range(1, rows + 1):
            on = solid(i, j) != solid(i + 1, j)
            n += on and not on_before
            on_before = on
    return n


RUNS = py_runs(MAZE)
TESTS = [
    ('T.Key(Lean.Style("posts=none|layers=-20,20"), "layers")', '-20,20'),
    ('T.Key(Lean.Style("posts=none|layers=-20,20"), "posts")', 'none'),
    # one layer: a 2x1 block is a rectangle of four lines (the line between the two cubes is gone)
    ('Lean.GridSegments("##", Lean.Style("layers=0"))',
     '0,0,0,0,0,16,wall\n0,0,0,32,0,0,wall\n0,0,16,32,0,16,wall\n32,0,0,32,0,16,wall'),
    # foot and top: 8 flat lines + 4 corner uprights; the one in the middle of the wall is gone
    ('the number of lines of Lean.GridSegments("##", empty)', '12'),
    ('"16,0,0,16,100,0,wall" is among the lines of Lean.GridSegments("##", empty)', 'false'),
    ('"0,0,0,0,100,0,wall" is among the lines of Lean.GridSegments("##", empty)', 'true'),
    ('the number of lines of Lean.GridSegments("##", Lean.Style("posts=all"))', '14'),
    ('the number of lines of Lean.GridSegments("##", Lean.Style("posts=none"))', '8'),
    # an L: the inside corner keeps its upright (lines leave it two ways)
    ('"16,0,16,16,100,16,wall" is among the lines of Lean.GridSegments("##" & return & "#.", empty)', 'true'),
    # floor lines go, touching runs join, other classes stay
    ('Lean.Segments("0,0,0,16,0,0,floor" & return & "16,0,0,32,0,0,wall" & return & "32,0,0,48,0,0,wall", empty)',
     '16,0,0,48,0,0,wall'),
    ('Lean.Segments("0,0,0,16,0,0,floor", Lean.Style("drop=none"))', '0,0,0,16,0,0,floor'),
    # a sloped line passes through as it is
    ('Lean.Segments("0,0,0,16,10,0,floor", empty)', '0,0,0,16,10,0,floor'),
    # DotMazeLean's maze, front and back, no posts: the same lines the game draws (2 x its runs)
    ('the number of lines of Lean.GridSegments(%s, Lean.Style("layers=-20,20|posts=none"))' % lc_text(MAZE), str(2 * RUNS)),
    # one mesh: as many lines; points shared between lines are made once
    ('T.Key(Lean.Walls(%s, 40, Lean.Style("layers=-20,20|posts=none|view=front")), "lines")' % lc_text(MAZE), str(2 * RUNS)),
    # the top-left corner of the maze, front layer, in DotMazeLean's units (cell 40, centred)
    ('"0,-20,0,304,-20,0,wall" is among the lines of Lean.GridSegments(%s, Lean.Style("layers=-20,20|posts=none"))' % lc_text(MAZE), 'true'),
    ('T.Point(Lean.Walls("#", 100, empty), 1)', '-50,0,-50'),
]


def main():
    c = Client.standalone()
    lib = local_to_win(LIB).replace('\\', '/')
    fake = FAKE.replace('"', '" & quote & "').replace('\n', '" & return & "')
    ok, out = c.run('if there is a stack "lib_lean" then delete stack "lib_lean"\n'
                    'if there is a stack "LeanFakeMesh" then delete stack "LeanFakeMesh"\n'
                    'create invisible stack "LeanFakeMesh"\n'
                    'set the script of stack "LeanFakeMesh" to "%s"\n'
                    'start using stack "LeanFakeMesh"\n'
                    'start using stack "%s"\nput "loaded"' % (fake, lib), in_server=True)
    if not ok or 'loaded' not in out:
        print('Could not load lib_lean:', out)
        return 2
    failed = 0
    for expr, want in TESTS:
        ok, got = c.eval(expr, in_server=True)
        got = got.replace('\r', '')
        good = ok and got == want
        failed += not good
        print('%s  %s' % ('PASS' if good else 'FAIL', expr[:110] if good else '%s\n      want %r\n      got  %r' % (expr[:200], want, got[:400])))
    c.run('stop using stack "%s"\nstop using stack "LeanFakeMesh"\ndelete stack "LeanFakeMesh"' % lib, in_server=True)
    print('\n%d of %d passed' % (len(TESTS) - failed, len(TESTS)))
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
