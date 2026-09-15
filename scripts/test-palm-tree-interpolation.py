#!/usr/bin/env python3
"""Compile the actual render function with controlled visibility and draw capture."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parent.parent
source = Path(sys.argv[1]) if len(sys.argv) > 1 else root / 'sources/spaghettikart/src/racing/actors.c'
text = source.read_text()
start = text.index('void render_palm_trees(')
end = text.index('\n#include "actors/trees/render.inc.c"', start)
with tempfile.TemporaryDirectory(prefix='spaghettipad-palm-test-') as temp:
    temp = Path(temp)
    (temp / 'render_palm_trees_under_test.inc').write_text(text[start:end])
    binary = temp / 'test'
    subprocess.run([os.environ.get('CXX', 'c++'), '-std=c++17', '-Wall', '-Wextra',
                    '-Wno-unused-variable', '-I' + str(temp),
                    str(root / 'tests/palm_tree_interpolation_test.cpp'), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
