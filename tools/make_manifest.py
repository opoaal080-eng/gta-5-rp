#!/usr/bin/env python3
"""Manifest for user-owned resources hosted at the same relative HTTPS paths."""
import argparse
import hashlib
import json
import os
from pathlib import Path

def sha(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for piece in iter(lambda: f.read(1024 * 1024), b""):
            h.update(piece)
    return h.hexdigest()

def manifest(root, name="RP resources", version="local-1"):
    root = Path(root).resolve(strict=True)
    if not root.is_dir():
        raise ValueError("Expected directory")
    files = []
    for folder, dirs, names in os.walk(root, followlinks=False):
        base = Path(folder)
        if any((base / d).is_symlink() for d in dirs):
            raise ValueError("Symlink directory not allowed")
        for name_in_folder in names:
            path = base / name_in_folder
            if path.is_symlink():
                raise ValueError("Symlink file not allowed")
            if not path.is_file():
                continue
            rel = path.relative_to(root).as_posix()
            if any(s in ("", ".", "..") for s in rel.split("/")):
                raise ValueError("Unsafe path")
            files.append({"path": rel, "size": path.stat().st_size, "sha256": sha(path)})
    files.sort(key=lambda f: f["path"])
    return {"schemaVersion": 1, "packageName": name, "version": version, "files": files}

if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("folder", type=Path)
    p.add_argument("--out", type=Path, default=Path("rp-manifest.json"))
    args = p.parse_args()
    result = manifest(args.folder)
    args.out.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf8")
    print(f"Created {args.out}; {len(result['files'])} entries. No assets copied.")
