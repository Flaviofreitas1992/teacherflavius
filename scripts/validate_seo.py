#!/usr/bin/env python3
"""Fail CI when core technical SEO invariants regress.

The validator intentionally uses only the Python standard library so it can run
on GitHub-hosted runners without installing dependencies.
"""

from __future__ import annotations

import json
import re
import sys
import xml.etree.ElementTree as ET
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
SITE_ORIGIN = "https://teacherflavius.com"
PRIVATE_PREFIXES = (
    "/login/",
    "/cadastro/",
    "/complete-cadastro/",
    "/area-do-estudante/",
    "/professor/",
    "/perfil/",
    "/minha-turma/",
    "/frequencia/",
    "/reposicoes/",
    "/mensalidades/",
    "/turmas/",
    "/flashcards/",
    "/meu-progresso/",
    "/minha-semana/",
    "/roteiro-de-estudos/",
    "/pagamento/",
)


class DocumentParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.title_depth = 0
        self.title_parts: list[str] = []
        self.h1_count = 0
        self.meta: dict[str, str] = {}
        self.og: dict[str, str] = {}
        self.links: list[dict[str, str]] = []
        self.anchors: list[str] = []
        self.json_ld: list[str] = []
        self._json_ld_depth = 0
        self._json_ld_parts: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attrs_dict = {key.lower(): (value or "") for key, value in attrs}
        tag = tag.lower()

        if tag == "title":
            self.title_depth += 1
        elif tag == "h1":
            self.h1_count += 1
        elif tag == "meta":
            name = attrs_dict.get("name", "").lower()
            prop = attrs_dict.get("property", "").lower()
            content = attrs_dict.get("content", "").strip()
            if name:
                self.meta[name] = content
            if prop.startswith("og:"):
                self.og[prop] = content
        elif tag == "link":
            self.links.append(attrs_dict)
        elif tag == "a":
            href = attrs_dict.get("href", "").strip()
            if href:
                self.anchors.append(href)
        elif tag == "script" and attrs_dict.get("type", "").lower() == "application/ld+json":
            self._json_ld_depth += 1
            self._json_ld_parts = []

    def handle_endtag(self, tag: str) -> None:
        tag = tag.lower()
        if tag == "title" and self.title_depth:
            self.title_depth -= 1
        elif tag == "script" and self._json_ld_depth:
            self._json_ld_depth -= 1
            text = "".join(self._json_ld_parts).strip()
            if text:
                self.json_ld.append(text)
            self._json_ld_parts = []

    def handle_data(self, data: str) -> None:
        if self.title_depth:
            self.title_parts.append(data)
        if self._json_ld_depth:
            self._json_ld_parts.append(data)

    @property
    def title(self) -> str:
        return " ".join(part.strip() for part in self.title_parts if part.strip()).strip()

    def canonical(self) -> str:
        for link in self.links:
            rel_tokens = {token.lower() for token in link.get("rel", "").split()}
            if "canonical" in rel_tokens:
                return link.get("href", "").strip()
        return ""


def parse_html(path: Path) -> DocumentParser:
    parser = DocumentParser()
    parser.feed(path.read_text(encoding="utf-8"))
    return parser


def is_absolute_https(url: str) -> bool:
    parsed = urlparse(url)
    return parsed.scheme == "https" and bool(parsed.netloc)


def main() -> int:
    errors: list[str] = []
    notices: list[str] = []

    def require(condition: bool, message: str) -> None:
        if not condition:
            errors.append(message)

    index_path = ROOT / "index.html"
    robots_path = ROOT / "robots.txt"
    sitemap_path = ROOT / "sitemap.xml"
    not_found_path = ROOT / "404.html"

    for path in (index_path, robots_path, sitemap_path, not_found_path):
        require(path.exists(), f"Arquivo obrigatório ausente: {path.relative_to(ROOT)}")

    if index_path.exists():
        index = parse_html(index_path)
        require(bool(index.title), "index.html precisa de <title> não vazio")
        require(10 <= len(index.title) <= 65, f"<title> da homepage tem tamanho incomum ({len(index.title)} caracteres)")

        description = index.meta.get("description", "")
        require(bool(description), "index.html precisa de meta description")
        require(70 <= len(description) <= 180, f"meta description da homepage tem tamanho incomum ({len(description)} caracteres)")

        robots = index.meta.get("robots", "").lower()
        require("noindex" not in robots, "homepage não pode conter noindex")
        require(index.h1_count == 1, f"homepage deve ter exatamente um H1; encontrado(s): {index.h1_count}")

        canonical = index.canonical()
        require(canonical == f"{SITE_ORIGIN}/", f"canonical da homepage deve ser {SITE_ORIGIN}/; encontrado: {canonical or 'ausente'}")

        required_og = ("og:type", "og:locale", "og:site_name", "og:title", "og:description", "og:url", "og:image", "og:image:width", "og:image:height", "og:image:alt")
        for key in required_og:
            require(bool(index.og.get(key)), f"Open Graph obrigatório ausente: {key}")
        require(index.og.get("og:url") == f"{SITE_ORIGIN}/", "og:url da homepage deve apontar para a URL canônica")
        require(is_absolute_https(index.og.get("og:image", "")), "og:image deve usar URL HTTPS absoluta")
        require(index.og.get("og:image:width") == "1200" and index.og.get("og:image:height") == "630", "imagem Open Graph deve declarar 1200x630")

        for key in ("twitter:card", "twitter:title", "twitter:description", "twitter:image"):
            require(bool(index.meta.get(key)), f"Twitter Card obrigatório ausente: {key}")
        require(index.meta.get("twitter:card") == "summary_large_image", "twitter:card deve ser summary_large_image")
        require(is_absolute_https(index.meta.get("twitter:image", "")), "twitter:image deve usar URL HTTPS absoluta")

        schema_types: set[str] = set()
        valid_json_ld = 0
        for block in index.json_ld:
            try:
                data = json.loads(block)
            except json.JSONDecodeError as exc:
                errors.append(f"JSON-LD inválido na homepage: {exc}")
                continue
            valid_json_ld += 1
            nodes = data.get("@graph", []) if isinstance(data, dict) else []
            if isinstance(nodes, dict):
                nodes = [nodes]
            if not nodes and isinstance(data, dict):
                nodes = [data]
            for node in nodes:
                if not isinstance(node, dict):
                    continue
                node_type = node.get("@type")
                if isinstance(node_type, str):
                    schema_types.add(node_type)
                elif isinstance(node_type, list):
                    schema_types.update(value for value in node_type if isinstance(value, str))
        require(valid_json_ld > 0, "homepage precisa de pelo menos um bloco JSON-LD válido")
        require("WebSite" in schema_types, "Schema.org da homepage deve incluir WebSite")
        require("Course" in schema_types, "Schema.org da homepage deve incluir Course")

        legacy_html_links = []
        for href in index.anchors:
            parsed = urlparse(href)
            if parsed.scheme or parsed.netloc:
                continue
            path = parsed.path
            if path.endswith(".html"):
                legacy_html_links.append(href)
        require(not legacy_html_links, f"homepage contém links internos legados .html: {', '.join(legacy_html_links)}")

    if robots_path.exists():
        robots_text = robots_path.read_text(encoding="utf-8")
        require(re.search(r"(?im)^User-agent:\s*\*$", robots_text) is not None, "robots.txt precisa declarar User-agent: *")
        require(re.search(rf"(?im)^Sitemap:\s*{re.escape(SITE_ORIGIN)}/sitemap\.xml\s*$", robots_text) is not None, "robots.txt precisa apontar para o sitemap canônico")
        for prefix in ("/login/", "/area-do-estudante/", "/professor/", "/mensalidades/"):
            require(re.search(rf"(?im)^Disallow:\s*{re.escape(prefix)}\s*$", robots_text) is not None, f"robots.txt deve bloquear crawling de {prefix}")

    if sitemap_path.exists():
        try:
            tree = ET.parse(sitemap_path)
            root = tree.getroot()
            namespace = "{http://www.sitemaps.org/schemas/sitemap/0.9}"
            locs = [(node.text or "").strip() for node in root.findall(f".//{namespace}loc")]
            require(bool(locs), "sitemap.xml precisa conter ao menos uma URL")
            require(len(locs) == len(set(locs)), "sitemap.xml contém URLs duplicadas")
            require(f"{SITE_ORIGIN}/" in locs, "sitemap.xml precisa conter a homepage canônica")
            for loc in locs:
                require(loc.startswith(f"{SITE_ORIGIN}/"), f"URL do sitemap fora do domínio canônico: {loc}")
                parsed = urlparse(loc)
                require(not parsed.query and not parsed.fragment, f"URL do sitemap não deve conter query/fragmento: {loc}")
                require(not parsed.path.endswith(".html"), f"URL legada .html encontrada no sitemap: {loc}")
                require(not any(parsed.path.startswith(prefix) for prefix in PRIVATE_PREFIXES), f"URL privada encontrada no sitemap: {loc}")
        except ET.ParseError as exc:
            errors.append(f"sitemap.xml inválido: {exc}")

    if not_found_path.exists():
        not_found = parse_html(not_found_path)
        require(bool(not_found.title), "404.html precisa de <title>")
        require(not_found.h1_count == 1, f"404.html deve ter exatamente um H1; encontrado(s): {not_found.h1_count}")
        robots = not_found.meta.get("robots", "").lower()
        require("noindex" in robots, "404.html precisa conter meta robots noindex")
        require(any(urlparse(href).path == "/" for href in not_found.anchors), "404.html precisa oferecer link para a homepage")
        require(any(urlparse(href).path == "/quero-conhecer/" for href in not_found.anchors), "404.html precisa oferecer link para /quero-conhecer/")
        require(not not_found.canonical(), "404.html não deve canonicalizar para uma página válida")

    if errors:
        print("Technical SEO audit: FAILED")
        for error in errors:
            print(f"::error::{error}")
        return 1

    print("Technical SEO audit: OK")
    print("Validated: title/description, canonical, H1, Open Graph, Twitter Card, JSON-LD, robots.txt, sitemap.xml and 404.html.")
    for notice in notices:
        print(f"::notice::{notice}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
