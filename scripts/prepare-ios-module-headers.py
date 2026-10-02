#!/usr/bin/env python3
"""Prepare private module headers using KartPad's hash-pinned SDK assembler."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import types
import urllib.request


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--kartpad-source", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    lock = json.loads(Path(__file__).with_name("ios-module-headers.json").read_text())
    repo, output = args.kartpad_source.resolve(), args.output.resolve()
    if output.exists():
        parser.error("output already exists; choose a new directory to preserve existing headers")
    for name, expected in lock["kartpad_files"].items():
        path = repo / name
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            parser.error(f"KartPad assembler input differs from the reviewed version: {name}")
    # Load only the two checked files, without executing an unrelated package initializer.
    package = types.ModuleType("_padmint_header_assembler")
    package.__path__ = []
    sys.modules[package.__name__] = package
    load_module(package.__name__ + ".errors", repo / "builder/kartpad_builder/errors.py")
    helper = load_module(package.__name__ + ".ios_sdk", repo / "builder/kartpad_builder/ios_sdk.py")
    roots = helper.source_roots()
    if repo == output or repo in output.parents or any(p.resolve() in output.parents for p in roots.values()):
        parser.error("output must be outside input source directories")
    output.parent.mkdir(parents=True, exist_ok=True)
    # The reused assembler deletes its destination first. Give it only a fresh child
    # of our private temporary directory; never pass an existing user directory.
    with tempfile.TemporaryDirectory(prefix="module-headers-", dir=output.parent) as temporary:
        sdk = Path(temporary) / "iPhoneOS-open-source.sdk"
        helper.assemble(repo, sdk, roots)
        records = []
        for header in lock["additional_headers"]:
            kind, origin = header["from"].split(":", 1)
            if "@" in origin:
                relative, revision = origin.split("@", 1)
                url = f"https://raw.githubusercontent.com/apple-oss-distributions/{kind}/{revision}/{relative}"
                with urllib.request.urlopen(url, timeout=60) as response:
                    data = response.read()
                source = url
            else:
                relative = origin
                if kind == "libc" and not relative.startswith("include/"):
                    relative = "include/" + relative
                if kind == "xnu" and relative.startswith("sys/"):
                    relative = "bsd/" + relative
                data = (roots[kind] / relative).read_bytes()
                source = kind + ":" + relative
            original_sha256 = hashlib.sha256(data).hexdigest()
            if kind == "libc":
                data = helper._strip_libc_blocks(data.decode("latin-1")).encode("latin-1")
            if kind in helper.INSTALL_DEFINES:
                data = helper._resolve_defines(data.decode("latin-1"), helper.INSTALL_DEFINES[kind]).encode("latin-1")
            if hashlib.sha256(data).hexdigest() != header["sha256"]:
                raise ValueError(f"Unexpected installed header bytes: {header['file']}")
            writer = helper._Writer(sdk)
            writer.write(header["file"], data, source, header["license"])
            records.extend([{**r, "source_sha256": original_sha256} for r in writer.records])
        provenance = sdk / "SOURCES.json"
        info = json.loads(provenance.read_text())
        info["files"].extend(records)
        info["assembler_files"] = lock["kartpad_files"]
        provenance.write_text(json.dumps(info, indent=2) + "\n")
        # Leave the reused assembler's SDK metadata unchanged. The module compiler
        # selects its own deployment target, whose runtime availability is unverified.
        if output.exists():
            raise FileExistsError(output)
        os.rename(sdk, output)
    print(f"Prepared {len(info['files'])} header records at {output}")


if __name__ == "__main__":
    main()
