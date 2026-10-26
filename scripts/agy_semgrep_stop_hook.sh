#!/usr/bin/env bash
# ==============================================================================
# Antigravity Stop hook (.agents/hooks.json): inner-loop Semgrep gate.
#
# When the Antigravity agent is about to finish a turn (terminationReason ==
# NO_TOOL_CALL) this hook:
#   1. Finds modified and untracked source files in the git workspace.
#   2. Runs Semgrep (--config auto) on just those files.
#   3. Converts results to CodeMender's import schema (/tmp/agy_semgrep_cm_import.json).
#   4. Prints {"decision":"continue","reason":"..."} so the agent receives the
#      findings and keeps working, or {} to let the turn finish.
#
# If a demo follow-mode run is active (~/.cm-demo/current_run), the hook also
# records its Semgrep run as events so the Mission Control UI shows it.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAW_JSON="/tmp/agy_semgrep_raw.json"
CM_IMPORT_JSON="/tmp/agy_semgrep_cm_import.json"

PAYLOAD="$(cat || true)"
TERM_REASON="$(printf '%s' "${PAYLOAD}" | jq -r '.terminationReason // "NO_TOOL_CALL"' 2>/dev/null || echo NO_TOOL_CALL)"
if [ "${TERM_REASON}" != "NO_TOOL_CALL" ]; then
  echo "{}"
  exit 0
fi

# Prefer semgrep on PATH, then the demo kit's .venv
SEMGREP="$(command -v semgrep || true)"
for candidate in "${SCRIPT_DIR}/../.venv/bin/semgrep" "${SCRIPT_DIR}/../../../.venv/bin/semgrep" "${CM_DEMO_KIT:-/nonexistent}/.venv/bin/semgrep"; do
  if [ -z "${SEMGREP}" ] && [ -x "${candidate}" ]; then
    SEMGREP="${candidate}"
  fi
done
if [ -z "${SEMGREP}" ]; then
  echo "{}"
  exit 0
fi

mapfile -t FILES < <(git status --porcelain 2>/dev/null \
  | awk '$1 != "D" {print $NF}' \
  | grep -E '\.(py|js|jsx|ts|tsx|go|java|rb|php|cs|kt)$' || true)
if [ "${#FILES[@]}" -eq 0 ]; then
  echo "{}"
  exit 0
fi

# Demo telemetry (optional): append to the active follow-mode run
EVENTS=""
if [ -f "${CM_DEMO_HOME:-$HOME/.cm-demo}/current_run" ]; then
  RUN_DIR="$(cat "${CM_DEMO_HOME:-$HOME/.cm-demo}/current_run")"
  [ -f "${RUN_DIR}/events.ndjson" ] && EVENTS="${RUN_DIR}/events.ndjson"
fi
STEP="hook-$(date +%s%3N)"
START_MS="$(date +%s%3N)"
emit() {
  [ -n "${EVENTS}" ] || return 0
  jq -nc --arg type "$1" --argjson ts "$(date +%s%3N)" --arg source antigravity-hook "${@:2}" '$ARGS.named' >> "${EVENTS}" 2>/dev/null || true
}
emit cmd_start --arg step "${STEP}" --arg cwd "${PWD}" \
  --arg cmd "semgrep scan --config auto --json --output ${RAW_JSON} ${FILES[*]}  # Antigravity Stop hook"

"${SEMGREP}" scan --config auto --quiet --json --output "${RAW_JSON}" "${FILES[@]}" >/dev/null 2>&1 || true

if [ -x "${SCRIPT_DIR}/semgrep_to_cm.sh" ]; then
  "${SCRIPT_DIR}/semgrep_to_cm.sh" "${RAW_JSON}" "${CM_IMPORT_JSON}" >/dev/null 2>&1 || true
fi

COUNT="$(jq '.results | length' "${RAW_JSON}" 2>/dev/null || echo 0)"
emit cmd_end --arg step "${STEP}" --arg cwd "${PWD}" \
  --argjson exit "$([ "${COUNT}" -gt 0 ] && echo 2 || echo 0)" \
  --argjson duration_ms "$(( $(date +%s%3N) - START_MS ))"

if [ "${COUNT}" -gt 0 ]; then
  SUMMARY="$(jq -r '.results[] | "- [\(.extra.severity)] \(.path):\(.start.line) \(.check_id | split(".") | last): \(.extra.message | split("\n")[0])"' "${RAW_JSON}" | head -n 8)"
  jq -n --arg count "${COUNT}" --arg summary "${SUMMARY}" --arg cm_file "${CM_IMPORT_JSON}" '{
    decision: "continue",
    reason: ("Inner-loop Semgrep gate: " + $count + " finding(s) in files you modified:\n" + $summary +
      "\n\nBefore finishing: (1) move any hardcoded secret to an environment variable; " +
      "(2) for injection or data-flow findings, use the codemender-triage-and-fix skill: " +
      "cm report import --file " + $cm_file + " --project-dir . then cm verify / cm fix the finding.")
  }'
  exit 0
fi

echo "{}"
