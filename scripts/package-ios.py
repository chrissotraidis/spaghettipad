#!/usr/bin/env python3
"""Package a device app after the existing platform/signing audit passes."""
import argparse
import hashlib
import os
from pathlib import Path
import plistlib
import re
import stat
import subprocess
import tempfile
import zipfile


ROOT = Path(__file__).resolve().parents[1]


def write_package(root, app, output, signed, dependency_root=None):
    """Serialize an already audited app; this is not an app/signature verifier."""
    info = plistlib.loads((app / "Info.plist").read_bytes())
    version, build = info.get("CFBundleShortVersionString"), info.get("CFBundleVersion")
    if (not isinstance(version, str) or not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version)
            or not isinstance(build, str) or not re.fullmatch(r"[1-9][0-9]*", build)):
        raise ValueError("Invalid release version/build")
    if info.get("CFBundleExecutable") != "SpaghettiPad":
        raise ValueError("Unexpected executable name")
    state = "signed" if signed else "unsigned"
    output = output or root / "artifacts" / f"SpaghettiPad-{version}-preview.{build}-{state}.ipa"
    if output.is_symlink() or output.resolve().is_relative_to(app.resolve()):
        raise ValueError("Output must not be a link or inside the application")

    entries = {}
    for path in sorted(app.rglob("*")):
        relative = path.relative_to(app).as_posix()
        if (path.suffix.lower() in (".z64", ".n64", ".v64", ".rom", ".otr")
                or (path.suffix.lower() == ".o2r" and path.name != "spaghetti.o2r")):
            raise ValueError("ROM-derived game data is embedded")
        if not signed and (relative.split("/")[0] == "_CodeSignature"
                           or relative == "embedded.mobileprovision"):
            raise ValueError("Unsigned app contains signing material")
        if path.is_symlink():
            target = os.readlink(path)
            if Path(target).is_absolute() or not path.resolve().is_relative_to(app.resolve()):
                raise ValueError("Application link escapes the bundle")
            entries["Payload/SpaghettiPad.app/" + relative] = (target.encode(), stat.S_IFLNK | 0o777)
        elif path.is_file():
            mode = 0o755 if relative == "SpaghettiPad" or path.stat().st_mode & 0o111 else 0o644
            entries["Payload/SpaghettiPad.app/" + relative] = (path.read_bytes(), stat.S_IFREG | mode)
    if "Payload/SpaghettiPad.app/SpaghettiPad" not in entries:
        raise ValueError("Application executable is missing")

    required = {
        "RIGHTS_AND_LICENSES.md": root / "RIGHTS_AND_LICENSES.md",
        "ThirdPartyLicenses/SDL_GameControllerDB.LICENSE": root / "THIRD_PARTY_NOTICES/SDL_GameControllerDB.LICENSE",
    }
    for name, path in required.items():
        if path.is_symlink() or not path.is_file() or not path.stat().st_size:
            raise ValueError("Required notice is missing: " + name)
        entries[name] = (path.read_bytes(), stat.S_IFREG | 0o644)
    notice_roots = [(root / "sources/spaghettikart", "sources/spaghettikart")]
    if dependency_root is None:
        notice_roots.append((root / "build-ios/_deps", "build-ios/_deps"))
    else:
        if dependency_root.is_symlink() or not dependency_root.is_dir():
            raise ValueError("Dependency notice directory is missing or is a link")
        notice_roots.append((dependency_root, "dependencies"))
    for directory, prefix in notice_roots:
        count = 0
        for path in sorted(directory.rglob("*")):
            if (path.is_file() and not path.is_symlink()
                    and path.name.upper().startswith(("LICENSE", "COPYING", "NOTICE"))):
                entries["ThirdPartyLicenses/" + prefix + "/" + path.relative_to(directory).as_posix()] = (
                    path.read_bytes(), stat.S_IFREG | 0o644)
                count += 1
        if dependency_root is not None and directory == dependency_root and not count:
            raise ValueError("Dependency notice directory contains no notices")

    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=output.parent, suffix=".partial", delete=False) as temporary:
        staging = Path(temporary.name)
    try:
        with zipfile.ZipFile(staging, "w", zipfile.ZIP_DEFLATED) as archive:
            for name, (data, mode) in sorted(entries.items()):
                member = zipfile.ZipInfo(name, (1980, 1, 1, 0, 0, 0))
                member.create_system = 3
                member.external_attr = mode << 16
                member.compress_type = zipfile.ZIP_DEFLATED
                archive.writestr(member, data)
        with zipfile.ZipFile(staging) as archive:
            if archive.testzip() is not None:
                raise ValueError("IPA ZIP integrity check failed")
        staging.replace(output)
    finally:
        staging.unlink(missing_ok=True)
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", nargs="?", type=Path, default=ROOT / "build-ios/Release-iphoneos/SpaghettiPad.app")
    parser.add_argument("output", nargs="?", type=Path)
    parser.add_argument("--dependency-root", type=Path,
                        help="Dependency source/build directory to collect notices from (default: build-ios/_deps)")
    args = parser.parse_args()
    app = args.app if args.app.is_absolute() else ROOT / args.app
    output = args.output
    if output is not None and not output.is_absolute():
        output = ROOT / output
    dependency_root = args.dependency_root
    if dependency_root is not None and not dependency_root.is_absolute():
        dependency_root = ROOT / dependency_root
    try:
        required = os.environ.get("REQUIRE_SIGNED", "0")
        if required not in ("0", "1"):
            raise ValueError("REQUIRE_SIGNED must be 0 or 1")
        env = dict(os.environ, REQUIRE_SIGNED=required, REQUIRE_UNSIGNED="0" if required == "1" else "1")
        # Keep every existing platform, resource and signature check. This audit
        # still needs macOS; portable serialization alone does not enable a host.
        subprocess.run([str(ROOT / "scripts/audit-ios-app.sh"), str(app)], env=env, check=True)
        output = write_package(ROOT, app, output, required == "1", dependency_root)
    except (ValueError, OSError, subprocess.CalledProcessError, plistlib.InvalidFileException) as error:
        parser.exit(1, f"IPA packaging: {error}\n")
    print(f"Packaged IPA: {output}")
    print(f"SHA256 {hashlib.sha256(output.read_bytes()).hexdigest()}")
    if required == "0":
        print("This proof artifact must be re-signed before standard-device installation.")


if __name__ == "__main__":
    main()
