#!/usr/bin/env python3
"""Deterministic operations for the playground skill.

Run from anywhere inside a playgrounds repo:
    python3 pg.py <init|new|validate|index|findings-files|clean> [options]

Errors exit 1 with a single "pg: ..." line on stderr.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import shutil
import subprocess
import sys
import time
import unicodedata
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parent.parent
TEMPLATES = SKILL_DIR / "templates"
MARKER = ".playgrounds"


class PgError(Exception):
    pass


def git(*args: str, cwd: Path | None = None) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["git", *args], cwd=cwd, capture_output=True, text=True, encoding="utf-8", errors="replace"
    )


def repo_root() -> Path:
    out = git("rev-parse", "--show-toplevel")
    if out.returncode != 0:
        raise PgError("not inside a git repository")
    return Path(out.stdout.strip())


def require_playgrounds(root: Path) -> None:
    if not (root / MARKER).is_file():
        raise PgError("not a playgrounds repo (no .playgrounds); run /spike init")


def write_new(path: Path, content: str) -> bool:
    """Write content unless the file exists. Returns True if written."""
    if path.exists():
        return False
    path.write_text(content, encoding="utf-8")
    return True


def cmd_init(args: argparse.Namespace) -> int:
    root = repo_root()
    files = {
        MARKER: "1\n",
        "README.md": (TEMPLATES / "repo" / "README.md").read_text(encoding="utf-8"),
        ".gitignore": (TEMPLATES / "repo" / "gitignore").read_text(encoding="utf-8"),
        "INDEX.md": render_index([]),
    }
    for name, content in files.items():
        if write_new(root / name, content):
            print(f"created {name}")
    return 0


KINDS = ("python", "ts", "infra", "bare")
RUBRIC_SCORES = ("dx", "docs", "performance", "maturity", "ecosystem", "ops_cost")
ENUMS = {
    "kind": KINDS,
    "mode": ("guided", "autopilot"),
    "durability": ("durable", "throwaway"),
    "status": ("active", "concluded", "abandoned"),
    "verdict": ("adopt", "trial", "hold", "reject", None),
}
QUESTION_ENUMS = {
    "answer": ("yes", "no", "partial", "blocked", None),
    "confidence": ("high", "medium", "low", None),
}
LICENSES = ("ok", "caution", "blocker", None)
FIELDS = (
    "slug", "tech", "version", "kind", "use_case", "mode", "durability", "status",
    "created", "concluded", "questions", "rubric", "verdict", "verdict_draft", "compared_with",
)


def is_date(value: object) -> bool:
    if not isinstance(value, str):
        return False
    try:
        dt.date.fromisoformat(value)
    except ValueError:
        return False
    return len(value) == 10


def validate_meta(meta: dict, dir_name: str | None = None) -> list[str]:
    """Return a list of human-readable problems; empty means valid."""
    if not isinstance(meta, dict):
        return ["playground.json must be a JSON object"]
    errs = [f"missing field '{k}'" for k in FIELDS if k not in meta]
    errs += [f"unknown field '{k}'" for k in meta if k not in FIELDS]
    for key, allowed in ENUMS.items():
        if key in meta and meta[key] not in allowed:
            errs.append(f"{key} must be one of {', '.join(str(a) for a in allowed)}")
    for key in ("slug", "tech", "use_case"):
        if key in meta and not (isinstance(meta[key], str) and meta[key].strip()):
            errs.append(f"{key} must be a non-empty string")
    if "version" in meta and meta["version"] is not None and not isinstance(meta["version"], str):
        errs.append("version must be a string or null")
    if "created" in meta and not is_date(meta["created"]):
        errs.append("created must be a YYYY-MM-DD date")
    if "concluded" in meta and meta["concluded"] is not None and not is_date(meta["concluded"]):
        errs.append("concluded must be null or a YYYY-MM-DD date")
    if "verdict_draft" in meta and not isinstance(meta["verdict_draft"], bool):
        errs.append("verdict_draft must be true or false")
    if "compared_with" in meta and not (
        isinstance(meta["compared_with"], list) and all(isinstance(s, str) for s in meta["compared_with"])
    ):
        errs.append("compared_with must be a list of slugs")
    errs += _validate_questions(meta.get("questions", []))
    errs += _validate_rubric(meta.get("rubric", {}))
    if meta.get("status") == "concluded":
        if meta.get("verdict") is None:
            errs.append("a concluded playground needs a verdict")
        if meta.get("concluded") is None:
            errs.append("a concluded playground needs a concluded date")
        if meta.get("verdict_draft") is True:
            errs.append("a concluded playground cannot have verdict_draft: true")
    if dir_name is not None and meta.get("slug") != dir_name:
        errs.append(f"slug '{meta.get('slug')}' does not match directory '{dir_name}'")
    return errs


def _validate_questions(questions: object) -> list[str]:
    if not isinstance(questions, list):
        return ["questions must be a list"]
    errs: list[str] = []
    for i, q in enumerate(questions):
        where = f"questions[{i}]"
        if not isinstance(q, dict):
            errs.append(f"{where} must be an object")
            continue
        keys = ("id", "text", "answer", "confidence", "experiment")
        errs += [f"{where} missing '{k}'" for k in keys if k not in q]
        errs += [f"{where} unknown field '{k}'" for k in q if k not in keys]
        for k in ("id", "text"):
            if k in q and not (isinstance(q[k], str) and q[k].strip()):
                errs.append(f"{where}.{k} must be a non-empty string")
        for k, allowed in QUESTION_ENUMS.items():
            if k in q and q[k] not in allowed:
                errs.append(f"{where}.{k} must be one of {', '.join(str(a) for a in allowed)}")
        if q.get("experiment") is not None and not isinstance(q["experiment"], str):
            errs.append(f"{where}.experiment must be a string or null")
    return errs


def _validate_rubric(rubric: object) -> list[str]:
    if not isinstance(rubric, dict):
        return ["rubric must be an object"]
    keys = (*RUBRIC_SCORES, "license")
    errs = [f"rubric missing '{k}'" for k in keys if k not in rubric]
    errs += [f"rubric unknown field '{k}'" for k in rubric if k not in keys]
    for k in RUBRIC_SCORES:
        v = rubric.get(k)
        if v is not None and (isinstance(v, bool) or not isinstance(v, int) or not 1 <= v <= 5):
            errs.append(f"rubric.{k} must be an integer 1-5 or null")
    if rubric.get("license") not in LICENSES:
        errs.append("rubric.license must be one of ok, caution, blocker, None")
    return errs


def load_meta(path: Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as e:
        raise PgError(f"cannot read {path}: {e}") from None


def playground_dirs(root: Path) -> list[Path]:
    return sorted(p.parent for p in (root / "pg").glob("*/playground.json"))


def cmd_validate(args: argparse.Namespace) -> int:
    root = repo_root()
    require_playgrounds(root)
    if args.slug:
        d = root / "pg" / args.slug
        if not (d / "playground.json").is_file():
            raise PgError(f"no playground {args.slug}")
        dirs = [d]
    else:
        dirs = playground_dirs(root)
    bad = False
    for d in dirs:
        try:
            errs = validate_meta(load_meta(d / "playground.json"), d.name)
        except PgError as e:
            errs = [str(e)]
        for err in errs:
            print(f"{d.name}: {err}")
        if errs:
            bad = True
        else:
            print(f"ok {d.name}")
    return 1 if bad else 0


PLACEHOLDER = re.compile(r"\{\{(slug|tech|use_case|created|questions)\}\}")


def slugify(text: str) -> str:
    text = text.replace("+", "plus").replace("#", "sharp")
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode()
    text = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return text[:40].rstrip("-")


def render(text: str, values: dict) -> str:
    # One pass, so a value that itself contains "{{slug}}" is left alone.
    return PLACEHOLDER.sub(lambda m: values[m.group(1)], text)


def one_line(text: str) -> str:
    """Collapse whitespace so free text can't break a markdown heading."""
    return " ".join(text.split())


def render_questions(questions: list[dict]) -> str:
    if not questions:
        return "_No questions yet._"
    blocks = [
        f"### {q['id']}: {one_line(q['text'])}\n- Answer: _pending_\n- Confidence:\n- Evidence:"
        for q in questions
    ]
    return "\n\n".join(blocks)


def cmd_new(args: argparse.Namespace) -> int:
    root = repo_root()
    require_playgrounds(root)
    if args.kind not in KINDS:
        raise PgError(f"unknown kind '{args.kind}' ({'|'.join(KINDS)})")
    base_text = args.name if args.name else args.tech
    base = re.sub(r"^\d{4}-\d{2}-\d{2}-", "", slugify(base_text))  # --name may be a full slug
    if not base:
        raise PgError(f"cannot derive a slug from '{base_text}'; pass --name")
    if base.endswith("-findings") or base == "findings":
        raise PgError(f"slug '{base}' clashes with the '-findings' suffix reserved for findings branches; pass --name")
    created = args.date or dt.date.today().isoformat()
    if not is_date(created):
        raise PgError(f"--date must be YYYY-MM-DD, got '{created}'")
    slug = f"{created}-{base}"
    dest = root / "pg" / slug
    if dest.exists():
        raise PgError(f"playground {slug} already exists; pass --name")

    questions = [
        {"id": f"Q{i}", "text": t, "answer": None, "confidence": None, "experiment": None}
        for i, t in enumerate(args.question or [], start=1)
    ]
    meta = {
        "slug": slug, "tech": args.tech, "version": None, "kind": args.kind,
        "use_case": args.use_case, "mode": args.mode, "durability": args.durability,
        "status": "active", "created": created, "concluded": None,
        "questions": questions,
        "rubric": {**{k: None for k in RUBRIC_SCORES}, "license": None},
        "verdict": None, "verdict_draft": False, "compared_with": [],
    }
    errs = validate_meta(meta, slug)
    if errs:
        raise PgError("; ".join(errs))

    values = {
        "slug": slug, "tech": one_line(args.tech), "use_case": one_line(args.use_case),
        "created": created, "questions": render_questions(questions),
    }
    dest.mkdir(parents=True)
    try:
        write_playground(dest, args.kind, values, meta)
    except (OSError, UnicodeError) as e:
        shutil.rmtree(dest, ignore_errors=True)
        raise PgError(f"could not write playground {slug}: {e}") from None
    print(slug)
    return 0


def write_playground(dest: Path, kind: str, values: dict, meta: dict) -> None:
    src = TEMPLATES / kind
    for f in sorted(src.rglob("*")):
        if f.is_dir():
            continue
        out = dest / f.relative_to(src)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(render(f.read_text(encoding="utf-8"), values), encoding="utf-8")
        out.chmod(f.stat().st_mode & 0o777)
    (dest / "experiments").mkdir(exist_ok=True)
    (dest / "experiments" / ".gitkeep").touch()
    findings = (SKILL_DIR / "references" / "findings-template.md").read_text(encoding="utf-8")
    (dest / "FINDINGS.md").write_text(render(findings, values), encoding="utf-8")
    (dest / "playground.json").write_text(json.dumps(meta, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


INDEX_HEADER = "<!-- generated by pg.py index; do not edit -->\n# Playgrounds\n"
INDEX_COLUMNS = (
    "Playground", "Tech", "Version", "Status", "Verdict",
    "DX", "Docs", "Perf", "Maturity", "Eco", "Ops", "License", "Created",
)


def cell(value: object) -> str:
    if value is None:
        return "\u2013"
    return " ".join(str(value).replace("|", "\\|").split())


def index_row(m: dict) -> str:
    verdict = cell(m["verdict"])
    if m["verdict"] is not None and m["verdict_draft"]:
        verdict += " (draft)"
    slug = m["slug"]
    cells = [
        f"[{slug}](pg/{slug}/FINDINGS.md)", cell(m["tech"]), cell(m["version"]),
        m["status"], verdict,
        *(cell(m["rubric"][k]) for k in RUBRIC_SCORES),
        cell(m["rubric"]["license"]), m["created"],
    ]
    return "| " + " | ".join(cells) + " |"


def render_index(metas: list[dict]) -> str:
    if not metas:
        return INDEX_HEADER + "\n_No playgrounds yet._\n"
    groups: dict[str, list[dict]] = {}
    for m in metas:
        groups.setdefault(cell(m["use_case"]), []).append(m)
    out = [INDEX_HEADER]
    for use_case in sorted(groups, key=str.lower):
        rows = sorted(groups[use_case], key=lambda m: m["slug"])
        rows.sort(key=lambda m: m["created"], reverse=True)
        out.append(f"## {use_case}\n")
        out.append("| " + " | ".join(INDEX_COLUMNS) + " |")
        out.append("|" + "---|" * len(INDEX_COLUMNS))
        out.extend(index_row(m) for m in rows)
        out.append("")
    return "\n".join(out)


def cmd_index(args: argparse.Namespace) -> int:
    root = repo_root()
    require_playgrounds(root)
    metas = []
    for d in playground_dirs(root):
        try:
            meta = load_meta(d / "playground.json")
            errs = validate_meta(meta, d.name)
        except PgError as e:
            errs = [str(e)]
        if errs:
            print(f"pg: warning: skipping {d.name}: {errs[0]}", file=sys.stderr)
            continue
        metas.append(meta)
    (root / "INDEX.md").write_text(render_index(metas), encoding="utf-8")
    print(f"wrote INDEX.md ({len(metas)} playgrounds)")
    return 0


def findings_paths(slug: str, files: list[str]) -> list[str]:
    """The findings subset of a playground's repo-relative file list, in output order."""
    base = f"pg/{slug}/"
    present = set(files)
    fixed = [base + n for n in ("playground.json", "FINDINGS.md", "README.md") if base + n in present]
    results = sorted(
        f for f in present
        if f.startswith(base + "experiments/") and f.count("/") == 4 and f.endswith("/RESULT.md")
    )
    return fixed + results


def cmd_findings_files(args: argparse.Namespace) -> int:
    root = repo_root()
    require_playgrounds(root)
    slug = args.slug
    if args.ref:
        # Read from a git ref, so this works from any checkout (e.g. on main
        # before switching to the findings branch).
        out = git("ls-tree", "-r", "--name-only", args.ref, "--", f"pg/{slug}/", cwd=root)
        files = out.stdout.splitlines() if out.returncode == 0 else []
        if f"pg/{slug}/playground.json" not in files:
            raise PgError(f"no playground {slug} at {args.ref}")
    else:
        d = root / "pg" / slug
        if not (d / "playground.json").is_file():
            raise PgError(f"no playground {slug}")
        files = [p.relative_to(root).as_posix() for p in d.rglob("*") if p.is_file()]
    for f in findings_paths(slug, files):
        print(f)
    return 0


def read_meta_at(root: Path, ref: str, slug: str) -> dict | None:
    """playground.json for slug as committed at ref, or None if absent/unreadable."""
    out = git("show", f"{ref}:pg/{slug}/playground.json", cwd=root)
    if out.returncode != 0:
        return None
    try:
        meta = json.loads(out.stdout)
    except ValueError:
        return None
    return meta if isinstance(meta, dict) else None


def pg_branches(root: Path) -> dict[str, dict[str, tuple[str, int]]]:
    """pg/* branches -> {"local"|"remote": (ref, committer unix time)}."""
    out = git(
        "for-each-ref", "--format=%(refname)%09%(committerdate:unix)",
        "refs/heads/pg/", "refs/remotes/origin/pg/", cwd=root,
    ).stdout.splitlines()
    branches: dict[str, dict[str, tuple[str, int]]] = {}
    for line in out:
        ref, _, stamp = line.partition("\t")
        if ref.startswith("refs/heads/"):
            name, where = ref[len("refs/heads/"):], "local"
        else:
            name, where = ref[len("refs/remotes/origin/"):], "remote"
        branches.setdefault(name, {})[where] = (ref, int(stamp or 0))
    return branches


def cmd_clean(args: argparse.Namespace) -> int:
    root = repo_root()
    require_playgrounds(root)
    has_origin = git("remote", "get-url", "origin", cwd=root).returncode == 0
    base = args.base or ("origin/main" if has_origin else "main")
    if git("rev-parse", "--verify", "--quiet", f"{base}^{{commit}}", cwd=root).returncode != 0:
        hint = "; run git fetch origin" if base.startswith("origin/") else ""
        raise PgError(f"base ref '{base}' not found{hint}")
    now = time.time()
    harvested: list[str] = []
    stale: list[str] = []
    for branch, places in sorted(pg_branches(root).items()):
        where = "both" if len(places) == 2 else next(iter(places))
        slug = branch[len("pg/"):]
        if slug.endswith("-findings"):
            slug = slug[: -len("-findings")]
        on_base = read_meta_at(root, base, slug)
        if on_base and on_base.get("status") in ("concluded", "abandoned"):
            harvested.append(f"harvested\t{branch}\t{where}")
            continue
        ref = places.get("local", places.get("remote"))[0]
        own = read_meta_at(root, ref, slug)
        age = int((now - max(t for _, t in places.values())) // 86400)
        if own and own.get("status") == "active" and age > args.days:
            stale.append(f"stale\t{branch}\t{age}\t{where}")
    for line in harvested + stale:
        print(line)
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="pg.py", description=__doc__)
    sub = p.add_subparsers(dest="command", required=True)
    sub.add_parser("init", help="set up a playgrounds repo").set_defaults(func=cmd_init)
    sub.add_parser("index", help="rebuild INDEX.md").set_defaults(func=cmd_index)
    n = sub.add_parser("new", help="scaffold a playground; prints its slug")
    n.add_argument("--tech", required=True)
    n.add_argument("--use-case", required=True)
    n.add_argument("--kind", required=True, help="|".join(KINDS))
    n.add_argument("--mode", required=True, choices=["guided", "autopilot"])
    n.add_argument("--durability", required=True, choices=["durable", "throwaway"])
    n.add_argument("--question", action="append", help="repeat for each question")
    n.add_argument("--name", help="slug text to use instead of --tech")
    n.add_argument("--date", help="YYYY-MM-DD (default: today)")
    n.set_defaults(func=cmd_new)
    f = sub.add_parser("findings-files", help="paths a throwaway merges to main")
    f.add_argument("slug")
    f.add_argument("--ref", help="read the playground from this git ref instead of the working tree")
    f.set_defaults(func=cmd_findings_files)
    c = sub.add_parser("clean", help="list harvested and stale pg/* branches (local and origin)")
    c.add_argument("--base", help="default: origin/main, or main when there is no origin")
    c.add_argument("--days", type=int, default=30)
    c.set_defaults(func=cmd_clean)
    v = sub.add_parser("validate", help="check playground.json files")
    v.add_argument("slug", nargs="?")
    v.set_defaults(func=cmd_validate)
    return p


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        return args.func(args)
    except PgError as e:
        print(f"pg: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
