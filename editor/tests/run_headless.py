#!/usr/bin/env python3
"""run_headless.py - run a LiveCode test body (tests/lc_*.txt) with the LiveCode 9.6.3 SERVER in
WSL: no window, no IDE, nothing on the owner's screen.

    python3 -I tests/run_headless.py tests/lc_v2_test.txt [more.txt ...]
    python3 -I tests/run_headless.py --root /some/copy/of/editor tests/lc_layout2_test.txt

A test body is message-box LiveCode that ends with `return tLog`. It is wrapped in a function of
a throw-away stack and its answer printed. The Windows path //wsl$/Ubuntu/home/... in a body
becomes /home/...; --root DIR replaces .../LIB_BIT/editor with DIR (so a test that rebuilds
BitEditor.livecode can run in a copy). "C:/LIB_MCP/" becomes the system temp folder.
The server has no screen: controls, scripts, imageData and files all work; snapshots, the mouse
and what a real window draws do not. Exit code 1 when a body throws or prints FAIL / false.
The server is $LIB_BIN/livecode-server/9.6.3-linux-x64/livecode-community-server.
"""
import os, subprocess, sys, tempfile

LIB_BIN = os.environ.get('LIB_BIN', os.path.expanduser('~/projects/LIB_BIN'))
SERVER = os.path.join(LIB_BIN, 'livecode-server', '9.6.3-linux-x64', 'livecode-community-server')
EDITOR = '/home/igame3d/projects/LIB_BIT/editor'

RUNNER = """<?lc
create stack "headless_runner"
put url ("binfile:%s") into tBody
put "function RunTest" & cr & "local tLog" & cr & tBody & cr & "end RunTest" into tScript
set the script of stack "headless_runner" to tScript
if the result is not empty then
  put "COMPILE ERROR: " & the result
else
  try
    put value("RunTest()", stack "headless_runner")
  catch tErr
    put "THREW: " & line 1 to 6 of tErr
  end try
end if
?>
"""


def main(argv):
    if not argv or argv[0] in ('-h', '--help'):
        print(__doc__)
        return 0
    root = EDITOR
    if argv[0] == '--root':
        root, argv = os.path.abspath(argv[1]), argv[2:]
    bad = False
    for path in argv:
        body = open(path, encoding='utf-8').read().replace('\r\n', '\n')
        body = body.replace('//wsl$/Ubuntu/home/', '/home/').replace(EDITOR, root)
        body = body.replace('C:/LIB_MCP/', tempfile.gettempdir() + '/')
        with tempfile.TemporaryDirectory() as tmp:
            b, r = os.path.join(tmp, 'body.txt'), os.path.join(tmp, 'run.lc')
            open(b, 'w', encoding='utf-8', newline='\n').write(body)
            open(r, 'w', encoding='utf-8', newline='\n').write(RUNNER % b)
            out = subprocess.run([SERVER, r], capture_output=True, text=True, timeout=600)
        text = (out.stdout + out.stderr).strip()
        print('== ' + path)
        print(text)
        if 'THREW' in text or 'COMPILE ERROR' in text or 'FAIL' in text or ': false' in text:
            bad = True
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
