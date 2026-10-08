#!/usr/bin/env python3
"""Build a reproducible Factorio Mod Portal ZIP using only Python's stdlib."""

import argparse
import json
from pathlib import Path
import re
import tempfile
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo


ROOT = Path(__file__).resolve().parents[1]
ASSET_DIRS = ("locale", "graphics", "sound", "migrations", "prototypes", "lib")
DOCUMENTS = ("info.json", "thumbnail.png", "changelog.txt", "README.md", "LICENSE", "LICENSE.md", "LICENSE.txt")


def build(output_dir: Path) -> Path:
    info = json.loads((ROOT / "info.json").read_text(encoding="utf-8"))
    name, version = info["name"], info["version"]
    if not re.fullmatch(r"[a-zA-Z0-9_-]+", name):
        raise ValueError("info.json: invalid mod name")
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise ValueError("info.json: version must have the form major.minor.patch")
    if info.get("factorio_version") != "2.0":
        raise ValueError("This release targets Factorio 2.0")
    for required in ("info.json", "data.lua", "control.lua", "settings.lua", "thumbnail.png"):
        if not (ROOT / required).is_file():
            raise ValueError(f"Missing required file: {required}")

    # Allowlist runtime files: never ship Git, AI configuration, scripts or old ZIPs.
    sources = set(ROOT.glob("*.lua"))
    sources.update(ROOT / filename for filename in DOCUMENTS if (ROOT / filename).is_file())
    for directory in ASSET_DIRS:
        folder = ROOT / directory
        if folder.is_dir():
            sources.update(path for path in folder.rglob("*") if path.is_file())
    sources = sorted(sources, key=lambda path: path.relative_to(ROOT).as_posix())
    for source in sources:
        if source.is_symlink() or not source.resolve().is_relative_to(ROOT):
            raise ValueError(f"File outside the source tree: {source}")

    output_dir = output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    prefix = f"{name}_{version}"
    destination = output_dir / f"{prefix}.zip"
    # Write beside the destination, then replace only after CRC/structure checks.
    with tempfile.NamedTemporaryFile(dir=output_dir, suffix=".zip", delete=False) as temporary:
        temporary_path = Path(temporary.name)
    try:
        with ZipFile(temporary_path, "w", compression=ZIP_DEFLATED, compresslevel=9) as archive:
            for source in sources:
                entry = ZipInfo(f"{prefix}/{source.relative_to(ROOT).as_posix()}", (1980, 1, 1, 0, 0, 0))
                entry.compress_type = ZIP_DEFLATED
                entry.create_system = 3
                entry.external_attr = 0o100644 << 16
                archive.writestr(entry, source.read_bytes(), compresslevel=9)
        with ZipFile(temporary_path) as archive:
            if archive.testzip() is not None:
                raise ValueError("ZIP integrity check failed")
            packaged_info = json.loads(archive.read(f"{prefix}/info.json"))
            if packaged_info != info:
                raise ValueError("Packaged metadata does not match info.json")
        temporary_path.replace(destination)
    finally:
        temporary_path.unlink(missing_ok=True)
    print(f"Created {destination} ({len(sources)} files, {destination.stat().st_size:,} bytes)")
    return destination


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=ROOT / "dist")
    args = parser.parse_args()
    build(args.output_dir)
