#!/usr/bin/env python3
"""Fetch pinned experimental module source inputs into a new private directory."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import urllib.request


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    script = Path(__file__).resolve()
    spec = json.loads(script.with_name("ios-module-inputs.json").read_text())
    lock = json.loads((script.parent.parent / "sources.lock.json").read_text())
    for name, component in zip(("source", "runtime", "torch"), lock["components"]):
        if spec["repositories"][name] != {"url": component["repository"], "commit": component["commit"]}:
            parser.error("module input manifest must match the maintained source lock")
    output = args.output.resolve()
    if output.exists():
        parser.error("output already exists; choose a new directory")
    output.parent.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(prefix="module-inputs-", dir=output.parent))
    print(f"Preparing inputs in {staging}", flush=True)

    def git(path, *arguments):
        command = ["git", "-c", "core.autocrlf=false", "-c", "core.eol=lf",
                   "-c", "submodule.recurse=false", "-c", "fetch.recurseSubmodules=false",
                   "-C", str(path), *arguments]
        result = subprocess.run(command, capture_output=True, text=True)
        with (staging / "fetch.log").open("a", encoding="utf-8") as log:
            log.write(json.dumps(command) + "\n" + result.stdout + result.stderr)
        if result.returncode:
            raise RuntimeError(f"git failed; see {staging / 'fetch.log'}")
        return result.stdout.strip()

    for name, repo in spec["repositories"].items():
        target = staging / name
        target.mkdir(parents=True)
        git(target, "init", "--quiet")
        git(target, "remote", "add", "origin", repo["url"])
        sparse = repo.get("sparse")
        if sparse:
            git(target, "sparse-checkout", "init", "--cone")
            git(target, "sparse-checkout", "set", *sparse)
        git(target, "fetch", "--depth=1", "--no-tags", *(["--filter=blob:none"] if sparse else []),
            "origin", repo["commit"])
        git(target, "checkout", "--detach", "FETCH_HEAD")
        if git(target, "rev-parse", "HEAD") != repo["commit"]:
            raise RuntimeError(f"Unexpected revision for {name}")
        print(f"Fetched {name} at {repo['commit']}", flush=True)
    for name, item in spec["files"].items():
        print(f"Downloading {name}", flush=True)
        # curl's bounded connection handling avoids waiting on each unreachable
        # address returned for a host; it is supplied by supported desktop hosts.
        downloader = shutil.which("curl")
        if downloader:
            result = subprocess.run([downloader, "--fail", "--location", "--silent", "--show-error",
                                     "--connect-timeout", "10", "--max-time", "60", item["url"]],
                                    capture_output=True, check=True)
            data = result.stdout
        else:
            with urllib.request.urlopen(item["url"], timeout=10) as response:
                data = response.read()
        if hashlib.sha256(data).hexdigest() != item["sha256"]:
            raise ValueError(f"Unexpected download bytes: {name}")
        target = staging / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    patch = staging / "runtime/cmake/dependencies/patches/imgui-fixes-and-config.patch"
    git(staging / "dependencies/imgui-src", "apply", "--check", str(patch))
    git(staging / "dependencies/imgui-src", "apply", str(patch))
    shutil.copytree(staging / "dependencies/sdl2-src/include", staging / "sdl-compat/SDL2")
    # Reproduce libzip's public fixed-width type header for the arm64 iOS target.
    # A checked expected digest prevents a changed template/configuration passing.
    template = (staging / "dependencies/libzip-src/zipconf.h.in").read_text()
    values = {"libzip_VERSION": "1.11.4", "libzip_VERSION_MAJOR": "1", "libzip_VERSION_MINOR": "11",
              "libzip_VERSION_PATCH": "4", "LIBZIP_TYPES_INCLUDE":
              "#if !defined(__STDC_FORMAT_MACROS)\n#define __STDC_FORMAT_MACROS 1\n#endif\n#include <inttypes.h>"}
    for bits in (8, 16, 32, 64):
        for prefix in ("INT", "UINT"):
            values[f"ZIP_{prefix}{bits}_T"] = f"{'u' if prefix == 'UINT' else ''}int{bits}_t"
    for key, value in values.items():
        template = template.replace("${" + key + "}", value)
    template = template.replace("#cmakedefine ZIP_STATIC", "#define ZIP_STATIC")
    data = template.encode("utf-8")
    if "${" in template or hashlib.sha256(data).hexdigest() != spec["zipconf_sha256"]:
        raise ValueError("Generated zipconf.h differs from the validated iOS configuration")
    target = staging / "dependencies/libzip-build/zipconf.h"
    target.parent.mkdir(parents=True)
    target.write_bytes(data)
    (staging / "INPUTS.json").write_text(json.dumps(spec, indent=2) + "\n")
    if output.exists():
        raise FileExistsError(output)
    os.rename(staging, output)
    print(f"Prepared inputs: {output}")


if __name__ == "__main__":
    main()
