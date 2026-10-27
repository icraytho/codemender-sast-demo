---
name: codemender-triage-and-fix
description: >-
  Imports Semgrep findings into CodeMender in Gemini platform (cm report import), verifies whether
  each one is exploitable (cm verify), and generates validated patches (cm fix). Use when escalating
  Semgrep or Stop hook findings to CodeMender, or when the user asks to verify or fix a vulnerability.
---

# CodeMender triage, verification and fix

1. **Make sure the change is committed on a working branch.** `cm verify` and `cm fix` reset the
   workspace to the last commit (`git checkout HEAD -- . && git clean -fd`) before they start, so
   uncommitted files would be lost:
   ```bash
   git status --short
   ```

2. **Import the Semgrep findings** (written by the Stop hook or `./scripts/semgrep_to_cm.sh`):
   ```bash
   export GOOGLE_CLOUD_PROJECT="${GOOGLE_CLOUD_PROJECT:-gen-ai-test-ic1}"
   cm report import --file /tmp/agy_semgrep_cm_import.json --project-dir .
   cm report --status OPEN --sort time
   ```

3. **Verify** a finding (ID or unique prefix from `cm report`):
   ```bash
   cm verify <FINDING_ID> --yes --compact
   ```
   `cm verify` updates the finding status (for example `VERIFIED` or `DISMISSED`). Read the status
   with `cm report`; don't infer it from the exit code. Proof-of-concept files are written to
   `.exploit/` next to the code (`REPORT.md`, `LOG.md`, `exploit.sh`).

4. **Fix** verified findings and show the patch:
   ```bash
   cm fix <FINDING_ID> --yes --compact
   git diff
   ```

Keep the sandbox on: don't add `--unrestricted` or `--sandbox=false` on a workstation.
