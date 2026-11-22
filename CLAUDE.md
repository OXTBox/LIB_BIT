# LIB_BIT: notes for Claude Code

Read `README.md`. Keep every handler pure: no globals, fields, images or screen updates (one exception: `Lean.Walls`
in lib_lean calls the engine's Mesh.New / AddVertex / AddLine).
A grid is lines of "0"/"1"; handlers return grids without a trailing return.

- Compile-check: `~/projects/LIB_MCP/tools/lcmcp compile livecode/lib_bit.livecodescript`
- Test in real LiveCode: `python3 tests/run_tests.py`. Add a test with every new handler;
  take the expected answer from LiveCode when unsure.
- Stepped `repeat with` loops overshoot their end in LiveCode 9.6.3 (see LIB_MCP CLAUDE.md);
  use `repeat while`.
- Never name a parameter or variable `pLayer`: it does not compile (LiveCode reads `player`).
- Editor tests with no window: `python3 -I editor/tests/run_headless.py` (see `editor/README.md`).
  `tests/run_tests.py` starts the LIB_MCP standalone on the owner's desktop: ask first.
- The owner may run `Build.Editor` at any moment: keep `editor/livecode/*.livecodescript`
  compiling at every save (edit a copy, compile-check, then move it in).
