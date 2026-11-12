# LIB_BIT: notes for Claude Code

Read `README.md`. Keep every handler pure: no globals, fields, images or screen updates.
A grid is lines of "0"/"1"; handlers return grids without a trailing return.

- Compile-check: `~/projects/LIB_MCP/tools/lcmcp compile livecode/lib_bit.livecodescript`
- Test in real LiveCode: `python3 tests/run_tests.py`. Add a test with every new handler;
  take the expected answer from LiveCode when unsure.
- Stepped `repeat with` loops overshoot their end in LiveCode 9.6.3 (see LIB_MCP CLAUDE.md);
  use `repeat while`.
