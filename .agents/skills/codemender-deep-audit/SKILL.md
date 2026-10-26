---
name: codemender-deep-audit
description: >-
  Runs CodeMender in Gemini platform scans: the pre-PR diff scan with 2-hop caller and callee impact
  (cm find --diff), deep scans of a file or directory (cm find --deep), and a before/after comparison
  of findings after fixes (scripts/compare_reports.py). Use when the user asks to scan before a pull
  request, run a deep scan or audit, or compare findings after remediation.
---

# CodeMender scans and re-scan comparison

## 1. Pre-PR diff scan (same command as the CI gate)

```bash
export GOOGLE_CLOUD_PROJECT="${GOOGLE_CLOUD_PROJECT:-gen-ai-test-ic1}"
cm find . --diff=main --diff-depth=2 --fail-on=CRITICAL,HIGH --compact --yes
cm report --status OPEN
```

Exit code 1 means findings at or above `--fail-on` were found. Findings in code the branch did not
change are labelled `[LEGACY / UNTOUCHED]`.

## 2. Deep scan of a file or directory

Deep scans are exhaustive and cost more tokens than quick or diff scans; scope them to what matters.

```bash
cm find <PATH> --deep --compact --yes
cm report --sort time
cm stats --since 2h
```

## 3. Re-scan after fixes

```bash
cm report --format json > /tmp/cmdemo-pass1.json
# ... cm fix <FINDING_ID> --yes ... then scan the same path again
cm find <PATH> --deep --compact --yes
cm report --format json > /tmp/cmdemo-pass2.json
python3 ./scripts/compare_reports.py /tmp/cmdemo-pass1.json /tmp/cmdemo-pass2.json
```

Report the status changes exactly as `compare_reports.py` prints them; do not estimate or extrapolate.
