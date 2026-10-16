"""Compile coach/kb/habits/*.md (YAML front matter) into a mastery-plan.v1 file.

Writes the app's bundled seed plan, and with --coachsync also publishes to the shared
iCloud CoachSync folder using the contract's atomic rule (<name>.tmp, then rename).

Usage:
  python coach/tools/export_plan.py                 # App/Resources/seed-plan.json
  python coach/tools/export_plan.py --coachsync     # + CoachSync/to-apps/conormastery/plan.json
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path

import yaml

REPO = Path(__file__).resolve().parents[2]
HABITS = REPO / "coach" / "kb" / "habits"
PLAN_META = REPO / "coach" / "kb" / "plan.yaml"
SEED = REPO / "App" / "Resources" / "seed-plan.json"
COACHSYNC = Path(os.environ.get("COACHSYNC_DIR", r"C:\Users\cdfee\iCloudDrive\CoachSync"))
SOURCES = REPO / "coach" / "kb" / "sources"
RESEARCH = REPO / "coach" / "kb" / "research" / "RESEARCH.md"

KINDS = {"build", "avoid", "checklist", "timer", "focus", "sleep"}
DIFFICULTIES = {"easy", "medium", "hard"}
GROUPS = {"morning", "day", "night"}
SCHEDULE = re.compile(r"^(daily|weekdays:[1-7](,[1-7])*|every:[1-9]\d*|per-week:[1-7])$")
TIMESTAMP = re.compile(r"^\d{1,2}:\d{2}(:\d{2})?$")
REQUIRED = ["id", "title", "kind", "difficulty", "group", "schedule", "identity", "why", "full", "citations", "challenges"]


class PlanError(ValueError):
    pass


def front_matter(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    match = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not match:
        raise PlanError(f"{path.name}: missing front matter")
    return yaml.safe_load(match.group(1))


def validate_habit(habit: dict, name: str) -> list[str]:
    errors = [f"{name}: missing {key}" for key in REQUIRED if key not in habit]
    if errors:
        return errors
    if habit["kind"] not in KINDS:
        errors.append(f"{name}: bad kind {habit['kind']}")
    if habit["difficulty"] not in DIFFICULTIES:
        errors.append(f"{name}: bad difficulty {habit['difficulty']}")
    if habit["group"] not in GROUPS:
        errors.append(f"{name}: bad group {habit['group']}")
    if not SCHEDULE.match(str(habit["schedule"])):
        errors.append(f"{name}: bad schedule {habit['schedule']}")
    if habit["kind"] in {"timer", "focus"} and not habit.get("target_minutes"):
        errors.append(f"{name}: {habit['kind']} habit needs target_minutes")
    if habit["kind"] == "checklist" and not habit.get("steps"):
        errors.append(f"{name}: checklist needs steps")
    if not habit["challenges"]:
        errors.append(f"{name}: needs at least one challenge")
    for c in habit["citations"]:
        source = str(c.get("source", ""))
        locator = str(c.get("locator", "")).strip()
        if source.startswith("yt:") and not TIMESTAMP.match(locator):
            errors.append(f"{name}: video citation needs mm:ss, got {c}")
        if not source.startswith(("yt:", "book:", "res:")) or not locator:
            errors.append(f"{name}: citation needs yt:/book:/res: source and a locator, got {c}")
        if source.startswith("res:") and f"| {source[4:]} |" not in RESEARCH.read_text(encoding="utf-8"):
            errors.append(f"{name}: cites {source} but it is not a row in coach/kb/research/RESEARCH.md")
        if source.startswith("yt:") and not (SOURCES / f"{source[3:]}.md").exists():
            errors.append(f"{name}: cites {source} but coach/kb/sources/{source[3:]}.md is missing")
    return errors


def build_plan() -> dict:
    meta = yaml.safe_load(PLAN_META.read_text(encoding="utf-8")) if PLAN_META.exists() else {}
    files = sorted(HABITS.glob("*.md"))
    habits, errors = [], []
    for path in files:
        habit = front_matter(path)
        errors += validate_habit(habit, path.name)
        habits.append({k: v for k, v in habit.items() if v is not None})
    ids = [h.get("id") for h in habits]
    if len(set(ids)) != len(ids):
        errors.append("duplicate habit ids")
    order = meta.get("order", [])
    habits.sort(key=lambda h: order.index(h["id"]) if h.get("id") in order else len(order))
    if errors:
        raise PlanError("\n".join(errors))
    return {
        "format": "conor-mastery-plan",
        "version": 1,
        "generated_at": datetime.now().astimezone().isoformat(timespec="seconds"),
        "weekly_focus": meta.get("weekly_focus"),
        "notes": meta.get("notes", []),
        "habits": habits,
    }


def atomic_write(data: str, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    tmp = target.with_name(target.name + ".tmp")
    tmp.write_text(data, encoding="utf-8")
    os.replace(tmp, target)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--coachsync", action="store_true", help="also publish to the CoachSync folder")
    args = parser.parse_args()
    try:
        plan = build_plan()
    except PlanError as error:
        print(f"Plan invalid:\n{error}", file=sys.stderr)
        return 1
    text = json.dumps(plan, indent=1, ensure_ascii=False) + "\n"
    atomic_write(text, SEED)
    print(f"seed plan: {len(plan['habits'])} habits -> {SEED}")
    if args.coachsync:
        target = COACHSYNC / "to-apps" / "conormastery" / "plan.json"
        atomic_write(text, target)
        print(f"published -> {target}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
