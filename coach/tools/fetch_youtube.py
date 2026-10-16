"""Fetch English transcripts for every video in coach/sources.yaml.

Uses yt-dlp auto/manual subtitles (no API key). Writes coach/raw/youtube/<id>.md:
a header (title, channel, url, habits) and [mm:ss] paragraphs roughly every 30 s,
so KB notes can cite timestamps. Raw transcripts are git-ignored (copyrighted);
only Claude-written notes with citations go in coach/kb/.

Usage: python coach/tools/fetch_youtube.py [--only ID ...] [--force]
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "raw" / "youtube"
CUE = re.compile(r"^(\d{2}):(\d{2}):(\d{2})\.\d{3} --> ")
TAG = re.compile(r"<[^>]+>")
PARAGRAPH_SECONDS = 30


def load_sources() -> list[dict]:
    data = yaml.safe_load((ROOT / "sources.yaml").read_text(encoding="utf-8"))
    return data.get("youtube", [])


def parse_vtt(text: str) -> list[tuple[int, str]]:
    """Return (seconds, line) pairs with YouTube's rolling-caption duplicates removed."""
    out: list[tuple[int, str]] = []
    seen_tail: list[str] = []
    current = 0
    for raw in text.splitlines():
        match = CUE.match(raw)
        if match:
            h, m, s = map(int, match.groups())
            current = h * 3600 + m * 60 + s
            continue
        line = TAG.sub("", raw).strip()
        if not line or line.startswith(("WEBVTT", "Kind:", "Language:")) or line in seen_tail:
            continue
        out.append((current, line))
        seen_tail = (seen_tail + [line])[-3:]
    return out


def paragraphs(lines: list[tuple[int, str]]) -> list[str]:
    result: list[str] = []
    bucket: list[str] = []
    start = 0
    for seconds, line in lines:
        if bucket and seconds - start >= PARAGRAPH_SECONDS:
            result.append(f"[{start // 60:02d}:{start % 60:02d}] " + " ".join(bucket))
            bucket = []
        if not bucket:
            start = seconds
        bucket.append(line)
    if bucket:
        result.append(f"[{start // 60:02d}:{start % 60:02d}] " + " ".join(bucket))
    return result


def fetch(video: dict, force: bool) -> str:
    vid = video["id"]
    target = RAW / f"{vid}.md"
    if target.exists() and not force:
        return "cached"
    with tempfile.TemporaryDirectory() as tmp:
        cmd = [
            "yt-dlp", "--skip-download", "--write-subs", "--write-auto-subs",
            "--sub-langs", "en,en-orig", "--sleep-requests", "3", "--sleep-subtitles", "8", "--sub-format", "vtt", "--write-info-json",
            "-o", f"{tmp}/%(id)s.%(ext)s", f"https://www.youtube.com/watch?v={vid}",
        ]
        proc = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
        subs = sorted(Path(tmp).glob(f"{vid}*.vtt"), key=lambda p: ("orig" not in p.name, len(p.name)))
        info_file = Path(tmp) / f"{vid}.info.json"
        if proc.returncode != 0 or not subs or not info_file.exists():
            return f"FAILED: {proc.stderr.strip().splitlines()[-1] if proc.stderr.strip() else 'no subtitles'}"
        info = json.loads(info_file.read_text(encoding="utf-8"))
        body = paragraphs(parse_vtt(subs[0].read_text(encoding="utf-8", errors="replace")))
    header = [
        f"# {info.get('title', vid)}",
        "",
        f"- source: yt:{vid}",
        f"- channel: {info.get('channel', '?')}",
        f"- url: https://www.youtube.com/watch?v={vid}",
        f"- duration: {info.get('duration_string', '?')}",
        f"- habits: {', '.join(video.get('habits', []))}",
        "",
    ]
    RAW.mkdir(parents=True, exist_ok=True)
    target.write_text("\n".join(header + body) + "\n", encoding="utf-8")
    return f"ok ({len(body)} paragraphs)"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", nargs="*", default=None)
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()
    videos = [v for v in load_sources() if args.only is None or v["id"] in args.only]
    failures = 0
    for video in videos:
        status = fetch(video, args.force)
        failures += status.startswith("FAILED")
        print(f"{video['id']}: {status}  ({video.get('note', '')})")
    print(f"{len(videos) - failures}/{len(videos)} transcripts ready in {RAW}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
