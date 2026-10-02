#!/usr/bin/env python3
"""Apply the reviewed scene startup backport to the fetched SDL2 input only."""
from pathlib import Path
import re
import subprocess
import sys


def apply(source):
    version = (source / "include/SDL_version.h").read_text()
    values = [int(re.search(rf"#define SDL_{name}\s+(\d+)", version)[1])
              for name in ("MAJOR_VERSION", "MINOR_VERSION", "PATCHLEVEL")]
    if values != [2, 32, 10]:
        raise ValueError("the scene backport requires the reviewed SDL 2.32.10 input")
    patch = Path(__file__).resolve().parent.parent / "patches/sdl2-ios-scenes.patch"

    def git(*args):
        return subprocess.run(["git", "apply", *args, str(patch)], cwd=source,
                              capture_output=True, text=True)

    if git("--reverse", "--check").returncode == 0:
        print("SDL2 scene startup backport is already applied.")
        return
    if git("--check").returncode:
        raise ValueError("SDL2 UIKit sources differ from the reviewed patch; preserve them and use a fresh build folder")
    result = git()
    if result.returncode:
        raise ValueError(result.stderr.strip())
    print("Applied SDL2 scene startup backport.")


if __name__ == "__main__":
    try:
        apply(Path(sys.argv[1]))
    except (OSError, ValueError, IndexError, TypeError) as error:
        raise SystemExit(f"SDL2 scene startup: {error}")
