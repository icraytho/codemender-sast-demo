---
name: semgrep-inner-loop
description: >-
  Runs a fast Semgrep secrets and SAST scan on the files modified in the workspace, fixes hardcoded
  secrets inline, and prepares other findings for CodeMender. Use when the user asks to scan local
  changes for secrets or vulnerabilities, or after the Stop hook reports Semgrep findings.
---

# Semgrep inner-loop scan

1. **Modified files**:
   ```bash
   git status --porcelain | awk '$1 != "D" {print $NF}'
   ```

2. **Scan them** (writes JSON for the next step):
   ```bash
   semgrep scan --config auto --json --output /tmp/agy_semgrep_raw.json <FILES>
   ```

3. **Convert for CodeMender**:
   ```bash
   ./scripts/semgrep_to_cm.sh /tmp/agy_semgrep_raw.json /tmp/agy_semgrep_cm_import.json
   ```

4. **Triage**:
   * Hardcoded secrets (CWE-798): move the value to an environment variable now, then re-run step 2
     to confirm the finding is gone.
   * Injection and other data-flow findings (CWE-89, CWE-78, CWE-22, CWE-918): use the
     `codemender-triage-and-fix` skill to verify and fix them.
