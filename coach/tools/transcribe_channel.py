"""Transcribe every video on a YouTube channel locally with Whisper (no caption API, so no 429s).

Downloads audio with yt-dlp (paced), transcribes with faster-whisper on the GPU, and writes
coach/raw/youtube/<id>.md in the same format as fetch_youtube.py ([mm:ss] paragraphs every ~30 s),
so check_kb.py can verify citations. Resumable: videos with a transcript already are skipped.
Audio is deleted after each transcript. Model and caches live on D: (owner rule: nothing on C:).

Usage: python coach/tools/transcribe_channel.py [--channel URL] [--model small.en] [--limit N]
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "raw" / "youtube"
AUDIO = ROOT / "raw" / "audio"
MODEL_DIR = Path("D:/dev-data/whisper")
MONKE = "https://www.youtube.com/channel/UCC2nLqBUIy8bagyNMDRiRcA"
PARAGRAPH_SECONDS = 30
PACE_SECONDS = 4

os.environ.setdefault("HF_HOME", "D:/dev-data/hf")
# CUDA 12 cuBLAS/cuDNN were installed on D: (pip --target D:/tools/pylib/cuda12); expose their DLLs.
CUDA_LIBS = Path("D:/tools/pylib/cuda12/nvidia")
for sub in ("cublas", "cudnn", "cuda_nvrtc"):
    dll_dir = CUDA_LIBS / sub / "bin"
    if dll_dir.exists():
        os.environ["PATH"] = str(dll_dir) + os.pathsep + os.environ.get("PATH", "")
        if hasattr(os, "add_dll_directory"):
            os.add_dll_directory(str(dll_dir))


def list_videos(channel: str) -> list[dict]:
    videos: list[dict] = []
    for tab in ("videos", "shorts"):
        out = subprocess.run(
            ["yt-dlp", "--flat-playlist", "--print", "%(id)s\t%(title)s\t%(duration_string)s", f"{channel}/{tab}"],
            capture_output=True, text=True, encoding="utf-8", errors="replace",
        ).stdout
        for line in out.splitlines():
            parts = line.split("\t")
            if len(parts) >= 2:
                videos.append({"id": parts[0], "title": parts[1], "duration": parts[2] if len(parts) > 2 else "?",
                               "short": tab == "shorts"})
    return videos


def download_audio(video_id: str) -> Path | None:
    AUDIO.mkdir(parents=True, exist_ok=True)
    proc = subprocess.run(
        ["yt-dlp", "-f", "bestaudio[ext=m4a]/bestaudio", "--no-playlist", "-o", str(AUDIO / "%(id)s.%(ext)s"),
         f"https://www.youtube.com/watch?v={video_id}"],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
    )
    files = list(AUDIO.glob(f"{video_id}.*"))
    if proc.returncode != 0 or not files:
        print(f"  download failed: {proc.stderr.strip().splitlines()[-1] if proc.stderr.strip() else 'no file'}")
        return None
    return files[0]


def paragraphs(segments) -> list[str]:
    result, bucket, start = [], [], 0
    for seg in segments:
        if bucket and seg.start - start >= PARAGRAPH_SECONDS:
            result.append(f"[{int(start) // 60:02d}:{int(start) % 60:02d}] " + " ".join(bucket))
            bucket = []
        if not bucket:
            start = seg.start
        bucket.append(seg.text.strip())
    if bucket:
        result.append(f"[{int(start) // 60:02d}:{int(start) % 60:02d}] " + " ".join(bucket))
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--channel", default=MONKE)
    parser.add_argument("--model", default="small.en")
    parser.add_argument("--limit", type=int, default=0)
    args = parser.parse_args()

    from faster_whisper import WhisperModel  # imported late so --help works without a GPU

    videos = list_videos(args.channel)
    todo = [v for v in videos if not (RAW / f"{v['id']}.md").exists()]
    already = len(videos) - len(todo)
    if args.limit:
        todo = todo[: args.limit]
    print(f"{len(videos)} videos on channel, {len(todo)} to transcribe")
    (ROOT / "raw" / "channel-index.json").write_text(json.dumps(videos, indent=1, ensure_ascii=False), encoding="utf-8")

    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    model = WhisperModel(args.model, device="cuda", compute_type="int8_float16", download_root=str(MODEL_DIR))
    on_gpu = True

    done = failed = 0
    for n, video in enumerate(todo, 1):
        print(f"[{n}/{len(todo)}] {video['id']} {video['title'][:60]}")
        audio = download_audio(video["id"])
        if audio is None:
            failed += 1
            continue
        try:
            try:
                segments, _ = model.transcribe(str(audio), language="en", vad_filter=True)
                body = paragraphs(list(segments))
            except RuntimeError as error:
                if not on_gpu:
                    raise
                # CUDA libraries load lazily, so a broken GPU setup surfaces here: switch to CPU once.
                print(f"  GPU failed ({error}); switching to CPU")
                model = WhisperModel(args.model, device="cpu", compute_type="int8", download_root=str(MODEL_DIR))
                on_gpu = False
                segments, _ = model.transcribe(str(audio), language="en", vad_filter=True)
                body = paragraphs(list(segments))
        except Exception as error:
            print(f"  transcription failed: {error}")
            failed += 1
            continue
        finally:
            audio.unlink(missing_ok=True)
        header = [f"# {video['title']}", "", f"- source: yt:{video['id']}", "- channel: monke",
                  f"- url: https://www.youtube.com/watch?v={video['id']}", f"- duration: {video['duration']}",
                  f"- transcribed: whisper {args.model} (local)", "- habits: all", ""]
        RAW.mkdir(parents=True, exist_ok=True)
        (RAW / f"{video['id']}.md").write_text("\n".join(header + body) + "\n", encoding="utf-8")
        done += 1
        print(f"  ok ({len(body)} paragraphs)")
        time.sleep(PACE_SECONDS)
    print(f"done: {done} transcribed, {failed} failed, {already} already had transcripts")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
