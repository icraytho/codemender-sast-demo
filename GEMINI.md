# Workspace security rules (Antigravity in Gemini platform)

This workspace uses three layers of security checks:
1. **Inner loop (this workstation)**: a Semgrep secrets and SAST check on every agent turn
   (`.agents/hooks.json` Stop hook), with escalation to CodeMender in Gemini platform (`cm`) for
   verification and fixes.
2. **Pull requests (GitHub Actions)**: CodeMender diff scan with caller and callee impact
   (`cm find . --diff=origin/main --diff-depth=2`) next to Semgrep.
3. **Releases and full repository**: CodeMender scans of the release delta on version tags, and
   deep scans (`cm find <path> --deep`) when a full audit is needed.

## Rules for the agent

* **No hardcoded secrets.** Never write API keys, tokens, passwords or private keys in source files.
  Read them from environment variables (`process.env.NAME`) or Secret Manager.
* **When the Stop hook reports Semgrep findings** (the message starts with "Inner-loop Semgrep gate"):
  1. Move any hardcoded secret to an environment variable.
  2. For injection, path traversal or other data-flow findings, use the **`codemender-triage-and-fix`**
     skill: import `/tmp/agy_semgrep_cm_import.json` with `cm report import`, then `cm verify` and
     `cm fix` the finding.
* **Before opening a pull request**, use the **`codemender-deep-audit`** skill to run the same diff
  scan the CI gate runs (`cm find . --diff=main --diff-depth=2`).
* Keep the CodeMender sandbox on. Do not pass `--unrestricted` or `--sandbox=false` on a workstation.
