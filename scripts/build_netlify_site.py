#!/usr/bin/env python3
from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PUBLISH = ROOT / "_site"

BLOCKED_TOP_LEVEL = {
    ".git",
    ".github",
    ".netlify",
    "_site",
    "docs",
    "netlify",
    "scripts",
    "supabase",
    "tests",
}

SKIP_NAMES = {"CNAME", ".nojekyll"}

PUBLIC_SUFFIXES = {
    ".html", ".htm",
    ".css", ".js", ".mjs", ".json", ".xml", ".txt",
    ".ico", ".svg", ".png", ".jpg", ".jpeg", ".webp", ".gif", ".avif",
    ".pdf",
    ".mp3", ".wav", ".ogg", ".m4a",
    ".mp4", ".webm",
    ".woff", ".woff2", ".ttf", ".otf",
}


def tracked_files() -> list[Path]:
    result = subprocess.run(
        ["git", "ls-files", "-z"],
        cwd=ROOT,
        check=True,
        capture_output=True,
    )
    return [Path(raw.decode("utf-8")) for raw in result.stdout.split(b"\0") if raw]


def is_public(path: Path) -> bool:
    if not path.parts:
        return False
    if path.parts[0] in BLOCKED_TOP_LEVEL:
        return False
    if path.name in SKIP_NAMES:
        return False
    if any(part.startswith(".") for part in path.parts):
        return False
    return path.suffix.lower() in PUBLIC_SUFFIXES


def main() -> None:
    if PUBLISH.exists():
        shutil.rmtree(PUBLISH)
    PUBLISH.mkdir(parents=True)

    copied = 0
    for relative in tracked_files():
        if not is_public(relative):
            continue
        source = ROOT / relative
        if not source.is_file():
            continue
        destination = PUBLISH / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
        copied += 1

    headers = ROOT / "netlify" / "_headers"
    if not headers.is_file():
        raise SystemExit("Missing netlify/_headers")
    shutil.copy2(headers, PUBLISH / "_headers")

    required = [PUBLISH / "index.html", PUBLISH / "404.html", PUBLISH / "robots.txt", PUBLISH / "sitemap.xml"]
    missing = [str(path.relative_to(ROOT)) for path in required if not path.is_file()]
    if missing:
        raise SystemExit(f"Netlify build missing required public files: {', '.join(missing)}")

    forbidden_suffixes = {".md", ".sql", ".py", ".yml", ".yaml", ".toml"}
    leaked = [
        str(path.relative_to(PUBLISH))
        for path in PUBLISH.rglob("*")
        if path.is_file() and path.suffix.lower() in forbidden_suffixes
    ]
    if leaked:
        raise SystemExit(f"Operational files leaked into publish directory: {', '.join(leaked)}")

    print(f"Netlify publish directory ready: {copied} public files + _headers")


if __name__ == "__main__":
    main()
