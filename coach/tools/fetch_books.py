"""Fetch public-domain books listed in coach/sources.yaml (`books:` with `gutenberg:` ids or a local
`text:` path) and write coach/raw/books/<slug>.md with numbered paragraphs ([¶n]) so notes can cite
exact passages. Owned PDFs stay with coach-kb's OCR tools; this only handles plain text.

Usage: python coach/tools/fetch_books.py [--force]
"""
from __future__ import annotations

import argparse
import re
import sys
import urllib.request
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "raw" / "books"
START = re.compile(r"\*\*\* ?START OF (THE|THIS) PROJECT GUTENBERG EBOOK.*?\*\*\*", re.I)
END = re.compile(r"\*\*\* ?END OF (THE|THIS) PROJECT GUTENBERG EBOOK", re.I)
MIN_PARAGRAPH_CHARS = 40


def gutenberg_text(book_id: int) -> str:
    url = f"https://www.gutenberg.org/cache/epub/{book_id}/pg{book_id}.txt"
    request = urllib.request.Request(url, headers={"User-Agent": "conor-mastery-kb/0.1"})
    with urllib.request.urlopen(request, timeout=60) as response:
        text = response.read().decode("utf-8", errors="replace")
    start, end = START.search(text), END.search(text)
    return text[start.end() if start else 0 : end.start() if end else len(text)]


def paragraphs(text: str) -> list[str]:
    blocks = re.split(r"\n\s*\n", text.replace("\r\n", "\n"))
    cleaned = (" ".join(block.split()) for block in blocks)
    return [p for p in cleaned if len(p) >= MIN_PARAGRAPH_CHARS]


def fetch(book: dict, force: bool) -> str:
    slug = book["slug"]
    target = RAW / f"{slug}.md"
    if target.exists() and not force:
        return "cached"
    if "gutenberg" in book:
        text = gutenberg_text(int(book["gutenberg"]))
    elif "text" in book:
        text = Path(book["text"]).read_text(encoding="utf-8", errors="replace")
    else:
        return "SKIPPED: no gutenberg id or text path"
    body = paragraphs(text)
    header = [f"# {book.get('title', slug)}", "", f"- source: book:{slug}",
              f"- habits: {', '.join(book.get('habits', []))}", ""]
    RAW.mkdir(parents=True, exist_ok=True)
    target.write_text("\n".join(header + [f"[¶{i}] {p}" for i, p in enumerate(body, 1)]) + "\n", encoding="utf-8")
    return f"ok ({len(body)} paragraphs)"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()
    books = yaml.safe_load((ROOT / "sources.yaml").read_text(encoding="utf-8")).get("books", [])
    failures = 0
    for book in books:
        if "slug" not in book:
            continue
        try:
            status = fetch(book, args.force)
        except Exception as error:  # network/file problems are reported per book, never hidden
            status = f"FAILED: {error}"
        failures += status.startswith("FAILED")
        print(f"{book['slug']}: {status}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
