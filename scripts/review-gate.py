#!/usr/bin/env python3
"""Decides whether the AI review lets a PR merge.

Reads one findings file per reviewer (see review/findings.schema.json) and a
list of dismissals taken from the PR description.

Modes
  stub     No real reviewer is configured. Always passes, and says loudly that
           no AI review happened. Use only while a human approves every PR.
  enforce  Requires at least --min-reviewers reviewers with status "ok" from
           at least two different vendors. Fails on a reviewer error, and on
           any high-severity finding that is not dismissed with a reason.

A dismissal is a line in the PR description of the form
  dismiss <finding-id>: <reason>

Exit code 0 lets the merge go ahead; 1 blocks it; 2 means bad input.
Uses the standard library only, so it runs on any CI image.
"""
import argparse
import json
import pathlib
import re
import sys

SEVERITIES = ("high", "medium", "low")
PASSES = ("bugs", "security", "compliance")
STATUSES = ("ok", "stub", "error")
DISMISS = re.compile(r"^\s*[-*]?\s*dismiss\s+([A-Za-z0-9._-]+)\s*:\s*(\S.*)$", re.IGNORECASE)


def load_findings(path):
    """Returns the parsed file, or raises ValueError naming what is wrong."""
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError as exc:
        raise ValueError(f"{path.name}: not valid JSON ({exc})") from exc
    if not isinstance(data, dict):
        raise ValueError(f"{path.name}: top level must be an object")
    for key in ("reviewer", "vendor", "status", "findings"):
        if key not in data:
            raise ValueError(f"{path.name}: missing '{key}'")
    if data["status"] not in STATUSES:
        raise ValueError(f"{path.name}: status must be one of {STATUSES}")
    if not isinstance(data["findings"], list):
        raise ValueError(f"{path.name}: 'findings' must be a list")
    for i, finding in enumerate(data["findings"]):
        for key in ("id", "pass", "severity", "title"):
            if key not in finding:
                raise ValueError(f"{path.name}: finding {i} is missing '{key}'")
        if finding["severity"] not in SEVERITIES:
            raise ValueError(f"{path.name}: finding {finding['id']} has a bad severity")
        if finding["pass"] not in PASSES:
            raise ValueError(f"{path.name}: finding {finding['id']} has a bad pass")
    return data


def load_dismissals(path):
    """Maps finding id -> reason, from 'dismiss <id>: <reason>' lines."""
    dismissed = {}
    if path and path.exists():
        for line in path.read_text().splitlines():
            match = DISMISS.match(line)
            if match:
                dismissed[match.group(1)] = match.group(2).strip()
    return dismissed


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--findings-dir", required=True, type=pathlib.Path)
    parser.add_argument("--dismissals", type=pathlib.Path)
    parser.add_argument("--mode", choices=("stub", "enforce"), default="stub")
    parser.add_argument("--min-reviewers", type=int, default=2)
    args = parser.parse_args()

    files = sorted(args.findings_dir.glob("*.json")) if args.findings_dir.is_dir() else []
    reviews, problems = [], []
    for path in files:
        try:
            reviews.append(load_findings(path))
        except ValueError as exc:
            problems.append(str(exc))
    dismissed = load_dismissals(args.dismissals)

    print("### AI review gate")
    print()
    print(f"- Mode: `{args.mode}`")
    print(f"- Reviewers reporting: {len(reviews)}")
    for review in reviews:
        print(f"  - `{review['reviewer']}` ({review['vendor']}): {review['status']}, "
              f"{len(review['findings'])} finding(s)")

    if problems:
        print("\n**Unreadable findings files:**")
        for problem in problems:
            print(f"- {problem}")
        return 2

    if args.mode == "stub":
        print("\n> **No AI review ran on this PR.** The reviewer jobs are stubs. "
              "Until they are real, a human must approve every PR "
              "(use the shadow ruleset).")
        return 0

    blockers = []
    ok = [r for r in reviews if r["status"] == "ok"]
    for review in reviews:
        if review["status"] == "error":
            blockers.append(f"Reviewer `{review['reviewer']}` failed to run.")
        if review["status"] == "stub":
            blockers.append(f"Reviewer `{review['reviewer']}` is still a stub.")
    if len(ok) < args.min_reviewers:
        blockers.append(f"Only {len(ok)} reviewer(s) completed; {args.min_reviewers} are required.")
    if len({r["vendor"] for r in ok}) < 2 and args.min_reviewers >= 2:
        blockers.append("The completed reviewers come from fewer than two vendors.")

    open_high, waived = [], []
    for review in ok:
        for finding in review["findings"]:
            if finding["severity"] != "high":
                continue
            entry = (review["reviewer"], finding)
            (waived if finding["id"] in dismissed else open_high).append(entry)

    if waived:
        print("\n**High-severity findings dismissed in the PR description:**")
        for reviewer, finding in waived:
            print(f"- `{finding['id']}` ({reviewer}): {finding['title']} — "
                  f"reason: {dismissed[finding['id']]}")
    if open_high:
        print("\n**High-severity findings that block the merge:**")
        for reviewer, finding in open_high:
            where = f" — `{finding['file']}`" if finding.get("file") else ""
            print(f"- `{finding['id']}` ({reviewer}, {finding['pass']}): {finding['title']}{where}")
        blockers.append(f"{len(open_high)} high-severity finding(s) are open.")

    if blockers:
        print("\n**Blocked:**")
        for blocker in blockers:
            print(f"- {blocker}")
        print("\nFix the finding, or add `dismiss <finding-id>: <reason>` to the PR description.")
        return 1

    print("\nNo open high-severity findings.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
