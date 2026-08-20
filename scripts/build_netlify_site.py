#!/usr/bin/env python3
from __future__ import annotations

import json
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PUBLISH = ROOT / "_site"
RESPONSIVE_COMPAT_HREF = "/responsive_compat.css?v=20260820-1"
RESPONSIVE_COMPAT_LINK = f'  <link rel="stylesheet" href="{RESPONSIVE_COMPAT_HREF}">'
VIEWPORT_META = '  <meta name="viewport" content="width=device-width, initial-scale=1.0">'

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


def current_commit_sha() -> str:
    result = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


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


def inject_responsive_compat(html: str) -> tuple[str, bool]:
    closing_head = html.lower().find("</head>")
    if closing_head < 0:
        return html, False

    additions: list[str] = []
    lower_html = html.lower()
    if 'name="viewport"' not in lower_html and "name='viewport'" not in lower_html:
        additions.append(VIEWPORT_META)
    if "/responsive_compat.css" not in lower_html:
        additions.append(RESPONSIVE_COMPAT_LINK)

    if not additions:
        return html, False

    prefix = html[:closing_head]
    suffix = html[closing_head:]
    separator = "" if prefix.endswith("\n") else "\n"
    injected = "\n".join(additions)
    return f"{prefix}{separator}{injected}\n{suffix}", True


def write_health_check() -> None:
    payload = {
        "status": "ok",
        "service": "teacherflavius.com",
        "commit": current_commit_sha(),
        "generated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    }
    (PUBLISH / "health.json").write_text(
        json.dumps(payload, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )


def main() -> None:
    if PUBLISH.exists():
        shutil.rmtree(PUBLISH)
    PUBLISH.mkdir(parents=True)

    copied = 0
    enhanced_html = 0
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

        if relative.suffix.lower() in {".html", ".htm"}:
            html = destination.read_text(encoding="utf-8")
            html, enhanced = inject_responsive_compat(html)
            if enhanced:
                destination.write_text(html, encoding="utf-8")
                enhanced_html += 1

    headers = ROOT / "netlify" / "_headers"
    if not headers.is_file():
        raise SystemExit("Missing netlify/_headers")
    shutil.copy2(headers, PUBLISH / "_headers")

    write_health_check()

    required = [
        PUBLISH / "index.html",
        PUBLISH / "404.html",
        PUBLISH / "robots.txt",
        PUBLISH / "sitemap.xml",
        PUBLISH / "health.json",
    ]
    missing = [str(path.relative_to(ROOT)) for path in required if not path.is_file()]
    if missing:
        raise SystemExit(f"Netlify build missing required public files: {', '.join(missing)}")

    compat_stylesheet = PUBLISH / "responsive_compat.css"
    if not compat_stylesheet.is_file():
        raise SystemExit("Netlify build missing responsive_compat.css")

    forbidden_suffixes = {".md", ".sql", ".py", ".yml", ".yaml", ".toml"}
    leaked = [
        str(path.relative_to(PUBLISH))
        for path in PUBLISH.rglob("*")
        if path.is_file() and path.suffix.lower() in forbidden_suffixes
    ]
    if leaked:
        raise SystemExit(f"Operational files leaked into publish directory: {', '.join(leaked)}")

    print(
        f"Netlify publish directory ready: {copied} public files + _headers + health.json; "
        f"responsive/viewport baseline enhanced {enhanced_html} HTML files"
    )


if __name__ == "__main__":
    main()
