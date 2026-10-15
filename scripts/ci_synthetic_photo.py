#!/usr/bin/env python3
"""Verify a real LightStrike CLI library round trip using generated pixels only."""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import zlib


def chunk(kind: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)


def png(path: Path) -> None:
    width, height = 96, 64
    rows = b"".join(
        b"\x00" + b"".join(bytes(((x * 2 + y) % 256, (x + y * 3) % 256, (x * 3 + y * 2) % 256)) for x in range(width))
        for y in range(height)
    )
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(rows))
        + chunk(b"IEND", b"")
    )


def run(*args: str) -> list[dict]:
    completed = subprocess.run(args, text=True, capture_output=True, timeout=180)
    if completed.returncode:
        raise RuntimeError(f"{args!r} failed ({completed.returncode}):\n{completed.stdout}\n{completed.stderr}")
    lines = [json.loads(line) for line in completed.stdout.splitlines() if line.startswith("{")]
    if any(line.get("ok") is False for line in lines):
        raise RuntimeError(f"command failed: {lines!r}")
    return lines


def dimensions(path: Path) -> tuple[int, int]:
    data = path.read_bytes()
    if not data.startswith(b"\x89PNG\r\n\x1a\n") or data[12:16] != b"IHDR":
        raise AssertionError(f"{path} is not a PNG")
    return struct.unpack(">II", data[16:24])


def main() -> None:
    binary = str(Path(sys.argv[1]).resolve())
    out_dir = Path(sys.argv[2]).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="lightstrike-photo-") as temp:
        base = Path(temp)
        source, library, exported = base / "generated.png", base / "library", out_dir / "developed.png"
        png(source)
        before = hashlib.sha256(source.read_bytes()).hexdigest()
        edited = run(
            binary, "run", "--library", str(library), "--import", str(source),
            "develop.set", "control=light.exposure", "value=0.75",
            "app.export", f"path={exported}", "width=60",
        )
        if len(edited) != 2 or edited[-1]["result"]["width"] != 60:
            raise AssertionError(f"unexpected export result: {edited!r}")
        reopened = run(binary, "run", "--library", str(library), "--import", str(source), "develop.get")
        if reopened[0]["result"]["light"]["exposure"] != 0.75:
            raise AssertionError(f"edit was not persisted: {reopened!r}")
        if hashlib.sha256(source.read_bytes()).hexdigest() != before:
            raise AssertionError("the imported original changed")
        if dimensions(exported) != (60, 40):
            raise AssertionError(f"unexpected export dimensions: {dimensions(exported)!r}")

    # The same complete UI code path renders the About panel headlessly. This
    # does not claim a native window or platform graphics-driver acceptance.
    script = out_dir / "about.jsonl"
    script.write_text(
        json.dumps({"method": "ui.menu.invoke", "params": {"id": "app.about"}}) + "\n"
        + json.dumps({"method": "ui.screenshot"}) + "\n",
        encoding="utf-8",
    )
    about = out_dir / "about.png"
    run(binary, "snapshot", "--demo", "--script", str(script), "-o", str(about), "--size", "1280x800")
    if dimensions(about) != (1280, 800):
        raise AssertionError(f"unexpected About capture size: {dimensions(about)!r}")
    print(json.dumps({"source_sha256": before, "reopen_exposure": 0.75, "export_size": [60, 40], "about_size": [1280, 800]}))


if __name__ == "__main__":
    main()
