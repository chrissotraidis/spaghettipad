#!/usr/bin/env python3
"""Build the pinned clean port resources without a native game/Torch build."""
import argparse
import hashlib
from pathlib import Path
import tempfile
import zipfile


EXPECTED_CONTENT = "5ab6f5d8898cfdc3e8806b985bf84ec34b2d2968f158ac2e84359e45ff8564a0"


def content_hash(files):
    records = (hashlib.sha256(files[name]).hexdigest() + "  " + name + "\n"
               for name in sorted(files))
    return hashlib.sha256("".join(records).encode("utf-8")).hexdigest()


def build_archive(source, output, expected=EXPECTED_CONTENT):
    source, output = Path(source), Path(output)
    if not source.is_dir() or source.is_symlink():
        raise ValueError("Pinned resource directory is missing or is a link")
    files = {}
    for path in sorted(source.rglob("*")):
        if path.is_symlink():
            raise ValueError("Resource links are not supported")
        if path.is_file():
            name = path.relative_to(source).as_posix()
            if "\n" in name or "\r" in name:
                raise ValueError("Resource names must not contain newlines")
            files[name] = path.read_bytes()
    if not files or content_hash(files) != expected:
        raise ValueError("Clean port resource content hash changed; output preserved")
    if output.exists():
        if output.is_symlink():
            raise ValueError("Output is a link; preserved")
        with zipfile.ZipFile(output) as archive:
            names = [n for n in archive.namelist() if not n.endswith("/")]
            if len(names) != len(set(names)) or archive.testzip() is not None:
                raise ValueError("Existing archive is invalid; preserved")
            if {n: archive.read(n) for n in names} != files:
                raise ValueError("Existing archive differs; preserved")
        return
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=output.parent, suffix=".partial", delete=False) as tmp:
        temporary = Path(tmp.name)
    try:
        with zipfile.ZipFile(temporary, "w", zipfile.ZIP_DEFLATED) as archive:
            for name, data in sorted(files.items()):
                info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
                info.create_system = 3
                info.external_attr = 0o100644 << 16
                info.compress_type = zipfile.ZIP_DEFLATED
                archive.writestr(info, data)
        temporary.replace(output)
    finally:
        temporary.unlink(missing_ok=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    try:
        build_archive(args.source, args.output)
    except (ValueError, OSError, zipfile.BadZipFile) as error:
        parser.exit(1, f"Port archive: {error}\n")
    print(f"Clean port archive: {args.output} (content SHA256 {EXPECTED_CONTENT})")
