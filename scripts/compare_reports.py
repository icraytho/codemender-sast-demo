#!/usr/bin/env python3
"""Compares two `cm report --format json` exports and prints status changes.

Usage:
  cm report --format json > /tmp/cmdemo-pass1.json
  ... fix, re-scan ...
  cm report --format json > /tmp/cmdemo-pass2.json
  python3 scripts/compare_reports.py /tmp/cmdemo-pass1.json /tmp/cmdemo-pass2.json

Only reads the two files. Every number printed comes from them.
"""

import argparse
import json
import os
import sys
from typing import Any, Dict, List


def load(path: str) -> Dict[str, Dict[str, Any]]:
  with open(path, encoding="utf-8") as f:
    text = f.read()
  start = text.find("[")
  items: List[Dict[str, Any]] = json.loads(text[start:]) if start >= 0 else []
  return {str(i.get("finding_id")): i for i in items if i.get("finding_id")}


def label(item: Dict[str, Any]) -> str:
  fp = os.path.basename(str(item.get("file_path", "")))
  return f"{item.get('severity', '?'):8} {fp:22} {str(item.get('title', ''))[:60]}"


def main() -> int:
  ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
  ap.add_argument("before")
  ap.add_argument("after")
  args = ap.parse_args()
  before, after = load(args.before), load(args.after)

  changed, new, gone, same = [], [], [], 0
  for fid, item in after.items():
    if fid not in before:
      new.append(item)
    elif before[fid].get("status") != item.get("status"):
      changed.append((before[fid].get("status"), item.get("status"), item))
    else:
      same += 1
  for fid, item in before.items():
    if fid not in after:
      gone.append(item)

  print(f"Findings before: {len(before)}   after: {len(after)}")
  print()
  print("Status changes:")
  if not changed:
    print("  (none)")
  for old, cur, item in changed:
    print(f"  {old or '?':10} -> {cur or '?':10} {label(item)}")
  print()
  print("New findings in pass 2:")
  if not new:
    print("  (none)")
  for item in new:
    print(f"  {item.get('status', '?'):10}    {label(item)}")
  if gone:
    print()
    print("Present before, absent after:")
    for item in gone:
      print(f"  {item.get('status', '?'):10}    {label(item)}")
  print()
  print(f"Unchanged: {same}")
  return 0


if __name__ == "__main__":
  sys.exit(main())
