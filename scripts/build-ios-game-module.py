#!/usr/bin/env python3
"""Experimental game-module compiler; requires separately prepared open headers.

This does not build an IPA or establish native-host/device support. See
../docs/EXPERIMENTAL-IOS-MODULE.md before using its private output.
"""
import argparse
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile


def response_file(path, arguments):
    # LLVM response-file parsing supports quoted forward-slash paths on all hosts.
    path.write_text("\n".join('"' + str(x).replace("\\", "/").replace('"', '\\"') + '"'
                              for x in arguments) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("source", "runtime", "torch", "dependencies", "imgui", "sdl-compat", "sdk", "output"):
        parser.add_argument("--" + name, required=True, type=Path)
    parser.add_argument("--clang", required=True, type=Path)
    parser.add_argument("--linker", required=True, type=Path)
    parser.add_argument("--jobs", type=int, default=4)
    args = parser.parse_args()
    if args.jobs < 1:
        parser.error("--jobs must be positive")
    script = Path(__file__).resolve()
    spec = json.loads(script.with_name("ios-game-module.json").read_text())
    lock = json.loads((script.parent.parent / "sources.lock.json").read_text())
    pin = next(c["commit"] for c in lock["components"] if c["path"] == "sources/spaghettikart")
    if pin != spec["engine_commit"]:
        parser.error("module manifest must be reviewed for the current engine pin")
    roots = {name: str(getattr(args, name).resolve()) for name in
             ("source", "runtime", "torch", "dependencies", "imgui", "sdl_compat", "sdk")}
    roots["shell"] = str(script.parent.parent / "ios")
    # Driver names select LLVM's mode; resolving ld64.lld to its lld symlink
    # target loses the Mach-O driver selection.
    clang, linker = args.clang.absolute(), args.linker.absolute()
    roots["clang_headers"] = str(Path(subprocess.check_output(
        [str(clang), "-print-resource-dir"], text=True).strip()) / "include")
    for name, value in roots.items():
        if not Path(value).is_dir():
            parser.error(f"missing {name} directory: {value}")
    source = Path(roots["source"])
    head = subprocess.check_output(["git", "-C", str(source), "rev-parse", "HEAD"], text=True).strip()
    dirty = subprocess.check_output(["git", "-C", str(source), "status", "--porcelain", "--untracked-files=no",
                                     "--ignore-submodules=all"], text=True).strip()
    if head != spec["engine_commit"] or dirty:
        parser.error("engine must be clean at the manifest's exact commit")
    for name in spec["sources"]:
        if Path(name).is_absolute() or ".." in Path(name).parts or not (source / name).is_file():
            parser.error(f"invalid or missing source: {name}")
    output = args.output.resolve()
    # Keep generated files away from source/toolchain inputs.
    for root in roots.values():
        if output == Path(root) or Path(root) in output.parents:
            parser.error("output must be outside source and toolchain directories")
    output.mkdir(parents=True, exist_ok=True)
    build = Path(tempfile.mkdtemp(prefix="attempt-", dir=output))
    base = [x.format(**roots, engine_commit=head) for x in spec["arguments"]]

    def compile_one(name):
        command = base.copy()
        if name.endswith(".c"):
            command = [x for x in command if x not in ("-std=c++20", "-nostdinc++")]
            index = command.index(roots["sdk"] + "/usr/include/c++/v1")
            del command[index - 1:index + 1]
        else:
            command += ["-x", "c++"]
        if name == "src/port/Game.cpp":
            command.append("-Dmain=SDL_main")
        obj = build / (name + ".o")
        obj.parent.mkdir(parents=True, exist_ok=True)
        command += ["-MD", "-MF", str(obj) + ".d", "-c", str(source / name), "-o", str(obj)]
        rsp = obj.with_suffix(".rsp")
        response_file(rsp, command)
        result = subprocess.run([str(clang), "@" + str(rsp)], capture_output=True, text=True)
        obj.with_suffix(".log").write_text(result.stdout + result.stderr, encoding="utf-8")
        return {"source": name, "exit_code": result.returncode, "object": str(obj), "arguments": command}

    results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        for result in pool.map(compile_one, spec["sources"]):
            results.append(result)
            if len(results) % 20 == 0 or len(results) == len(spec["sources"]):
                print(f"Compiled {len(results)}/{len(spec['sources'])}; failures: "
                      f"{sum(x['exit_code'] != 0 for x in results)}", flush=True)
    report = {"engine_commit": head, "roots": roots, "clang": str(clang), "linker": str(linker), "compiles": results,
              "clang_version": subprocess.check_output([str(clang), "--version"], text=True),
              "linker_version": subprocess.check_output([str(linker), "--version"], text=True)}
    report_path = build / "results.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    if any(x["exit_code"] for x in results):
        raise SystemExit(f"Compilation failed; logs retained at {build}; previous module preserved")
    candidate = build / "SpaghettiGame.dylib"
    link_args = ["-dylib", "-arch", "arm64", "-platform_version", "ios", "15.0", "15.0",
                 "-flat_namespace", "-undefined", "dynamic_lookup", "-L", roots["sdk"] + "/usr/lib",
                 "-lSystem", "-lc++", "-install_name", "@rpath/SpaghettiGame.dylib", "-o", str(candidate)]
    link_args += [x["object"] for x in results]
    rsp = build / "link.rsp"
    response_file(rsp, link_args)
    result = subprocess.run([str(linker), "@" + str(rsp)], capture_output=True, text=True)
    report["link"] = {"arguments": link_args, "exit_code": result.returncode,
                      "stdout": result.stdout, "stderr": result.stderr}
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    if result.returncode:
        raise SystemExit(f"Link failed; logs retained at {build}; previous module preserved")
    report["sha256"] = hashlib.sha256(candidate.read_bytes()).hexdigest()
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    os.replace(candidate, output / "SpaghettiGame.dylib")
    print(f"Private module: {output / 'SpaghettiGame.dylib'}\nEvidence: {report_path}")


if __name__ == "__main__":
    main()
