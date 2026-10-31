#!/usr/bin/env python3
"""Read-only local game files storage audit (Python 3.9+)."""
import argparse
import hashlib
import json
import os
from collections import defaultdict
from pathlib import Path

GiB = 1024 ** 3

def checksum(path):
    h = hashlib.sha256()
    with open(path, "rb") as file:
        for piece in iter(lambda: file.read(4 * 1024 * 1024), b""):
            h.update(piece)
    return h.hexdigest()

def audit(root, hash_duplicates=False):
    root = Path(root).resolve(strict=True)
    if not root.is_dir():
        raise ValueError("Expected a directory")
    rows = []
    warnings = []
    sizes = defaultdict(list)
    folders = defaultdict(int)
    types = defaultdict(int)
    for folder, dirs, names in os.walk(root, followlinks=False):
        current = Path(folder)
        dirs[:] = [d for d in dirs if not (current / d).is_symlink()]
        for name in names:
            file = current / name
            if file.is_symlink() or not file.is_file():
                continue
            rel = file.relative_to(root).as_posix()
            try:
                size = file.stat().st_size
            except OSError as e:
                warnings.append(f"{rel}: {e}")
                continue
            ext = file.suffix.lower() or "(no extension)"
            top = rel.split("/")[0] if "/" in rel else "(root)"
            folders[top] += size
            types[ext] += size
            rows.append({"path": rel, "size": size})
            if size:
                sizes[size].append((rel, file))
    duplicates = []
    saved = 0
    if hash_duplicates:
        for size, candidates in sizes.items():
            if len(candidates) < 2:
                continue
            hashed = defaultdict(list)
            for name, file in candidates:
                try:
                    hashed[checksum(file)].append(name)
                except OSError as e:
                    warnings.append(f"{name}: {e}")
            for digest, paths in hashed.items():
                if len(paths) > 1:
                    recovered = size * (len(paths) - 1)
                    duplicates.append({"sha256": digest, "size": size, "paths": paths, "potential_saving": recovered})
                    saved += recovered
    total = sum(row["size"] for row in rows)
    return {
        "source": str(root),
        "bytes": total, "files": len(rows),
        "folders": dict(sorted(folders.items(), key=lambda x: -x[1])),
        "extensions": dict(sorted(types.items(), key=lambda x: -x[1])),
        "largest": sorted(rows, key=lambda x: -x["size"])[:30],
        "sha256_checked": hash_duplicates,
        "exact_duplicate_savings": saved,
        "exact_duplicates": sorted(duplicates, key=lambda x: -x["potential_saving"]),
        "targets": {
            str(target): {"bytes_to_remove": max(0, total - target * GiB),
                          "percent_to_remove": round(100 * max(0, total - target * GiB) / total, 1) if total else 0}
            for target in (10, 5)
        },
        "warnings": warnings,
    }

def report_md(x):
    def gib(bytes_): return f"{bytes_ / GiB:.2f} GiB"
    lines = [
        "# GTA5RP: аудит игровых файлов",
        f"Каталог: \`{x['source']}\`",
        f"Всего: **{gib(x['bytes'])}**, файлов: **{x['files']}**.",
        "",
        "## Целевой размер на диске",
    ]
    for target, item in x["targets"].items():
        lines.append(f"- {target} GiB: нужно убрать {gib(item['bytes_to_remove'])} ({item['percent_to_remove']}%).")
    for title, key in (("Папки", "folders"), ("Расширения", "extensions")):
        lines.extend(["", "## " + title])
        lines += [f"- \`{name}\`: {gib(size)}" for name, size in list(x[key].items())[:25]]
    lines.extend(["", "## Крупнейшие файлы"])
    lines += [f"- {gib(row['size'])}: \`{row['path']}\`" for row in x["largest"]]
    lines.extend(["", "## Точные совпадения по SHA-256"])
    lines.append("Хеширование: " + ("проведено" if x["sha256_checked"] else "не проводилось"))
    lines.append("Общий размер *возможных* дублей: " + gib(x["exact_duplicate_savings"]))
    for item in x["exact_duplicates"][:10]:
        lines.append("- " + gib(item["potential_saving"]) + ": " + ", ".join("\`" + p + "\`" for p in item["paths"][:5]))
    lines.extend(["", "**Файлы не менялись.** Удалять подтверждённые дубли автоматически нельзя: разные пути могут быть нужны движку. Форматы RPF и WASM нельзя без проверки заменять обычными архивами."])
    return "\n".join(lines) + "\n"

def main():
    p = argparse.ArgumentParser()
    p.add_argument("folder", type=Path)
    p.add_argument("--hash-duplicates", action="store_true", help="Read same-sized files and SHA-256 compare them")
    p.add_argument("--json", type=Path, default=Path("asset-audit.json"))
    p.add_argument("--md", type=Path, default=Path("asset-audit.md"))
    args = p.parse_args()
    data = audit(args.folder, args.hash_duplicates)
    args.json.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    args.md.write_text(report_md(data), encoding="utf-8")
    print(f"Files {data['files']}, size {data['bytes'] / GiB:.2f} GiB; report: {args.md}, {args.json}")

if __name__ == "__main__":
    main()
