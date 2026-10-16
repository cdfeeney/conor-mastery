"""Verify KB citations against raw transcripts.

Every [mm:ss] in coach/kb/sources/<id>.md and every yt: citation in coach/kb/habits/*.md must land on
a paragraph marker that exists in coach/raw/youtube/<id>.md. A missing raw transcript is reported as
UNVERIFIABLE (fetch it first); it is never treated as a pass.

Usage: python coach/tools/check_kb.py
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "raw" / "youtube"
BOOKS = ROOT / "raw" / "books"
PARA = re.compile(r"\[¶(\d+)\]")
SOURCES = ROOT / "kb" / "sources"
HABITS = ROOT / "kb" / "habits"
MARK = re.compile(r"\[(\d{1,2}:\d{2})\]")


def markers(video_id: str) -> set[str] | None:
    path = RAW / f"{video_id}.md"
    if not path.exists():
        return None
    return set(re.findall(r"^\[(\d{2}:\d{2})\]", path.read_text(encoding="utf-8"), re.M))


def book_paragraphs(slug: str) -> set[str] | None:
    path = BOOKS / f"{slug}.md"
    if not path.exists():
        return None
    return set(re.findall(r"^\[¶(\d+)\]", path.read_text(encoding="utf-8"), re.M))


def normalise(ts: str) -> str:
    m, s = ts.split(":")[-2:]
    return f"{int(m):02d}:{int(s):02d}"


def check_sources() -> tuple[int, list[str]]:
    count, problems = 0, []
    for note in sorted(SOURCES.glob("book-*.md")):
        valid = book_paragraphs(note.stem[len("book-"):])
        if valid is None:
            problems.append(f"UNVERIFIABLE {note.name}: no raw book text")
            continue
        for n in PARA.findall(note.read_text(encoding="utf-8")):
            count += 1
            if n not in valid:
                problems.append(f"BAD {note.name}: [¶{n}] is not a paragraph in the book")
    for note in sorted(p for p in SOURCES.glob("*.md") if not p.name.startswith("book-")):
        valid = markers(note.stem)
        if valid is None:
            problems.append(f"UNVERIFIABLE {note.name}: no raw transcript")
            continue
        for ts in MARK.findall(note.read_text(encoding="utf-8")):
            count += 1
            if normalise(ts) not in valid:
                problems.append(f"BAD {note.name}: [{ts}] is not a paragraph marker")
    return count, problems


def check_habits() -> tuple[int, list[str]]:
    count, problems = 0, []
    for path in sorted(HABITS.glob("*.md")):
        match = re.match(r"^---\n(.*?)\n---\n", path.read_text(encoding="utf-8"), re.S)
        if not match:
            problems.append(f"BAD {path.name}: no front matter")
            continue
        for citation in yaml.safe_load(match.group(1)).get("citations", []):
            source = str(citation.get("source", ""))
            if source.startswith("book:"):
                count += 1
                slug = source[5:]
                found = re.search(r"¶(\d+)", str(citation.get("locator", "")))
                valid = book_paragraphs(slug)
                if not (SOURCES / f"book-{slug}.md").exists():
                    problems.append(f"BAD {path.name}: {source} has no note coach/kb/sources/book-{slug}.md")
                elif valid is None:
                    problems.append(f"UNVERIFIABLE {path.name}: {source} has no raw book text")
                elif not found or found.group(1) not in valid:
                    problems.append(f"BAD {path.name}: {source} @ {citation.get('locator')} is not a book paragraph")
                continue
            if not source.startswith("yt:"):
                continue
            count += 1
            valid = markers(source[3:])
            if valid is None:
                problems.append(f"UNVERIFIABLE {path.name}: {source} has no raw transcript")
            elif normalise(str(citation.get("locator"))) not in valid:
                problems.append(f"BAD {path.name}: {source} @ {citation.get('locator')} is not a paragraph marker")
    return count, problems


def main() -> int:
    source_count, source_problems = check_sources()
    habit_count, habit_problems = check_habits()
    problems = source_problems + habit_problems
    for line in problems:
        print(line)
    print(f"checked {source_count} note timestamps, {habit_count} habit citations: {len(problems)} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
