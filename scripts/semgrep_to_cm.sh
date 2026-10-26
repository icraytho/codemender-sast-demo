#!/usr/bin/env bash
# ==============================================================================
# Converts Semgrep JSON output into CodeMender `cm report import` JSON schema.
# Usage: ./scripts/semgrep_to_cm.sh <semgrep_raw.json> <cm_import.json>
# ==============================================================================
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <semgrep_raw.json> <cm_import.json>" >&2
  exit 1
fi

INPUT_JSON="$1"
OUTPUT_JSON="$2"

if [ ! -f "$INPUT_JSON" ]; then
  echo "Error: Input file '$INPUT_JSON' does not exist." >&2
  exit 1
fi

jq '[
  .results[]? | {
    file_path: .path,
    line: (.start.line // 1),
    title: (.check_id | split(".") | last),
    message: (.extra.message // "Imported from Semgrep SAST"),
    severity: (
      if (.extra.severity | ascii_upcase) == "ERROR" then "HIGH"
      elif (.extra.severity | ascii_upcase) == "WARNING" then "MEDIUM"
      else "LOW"
      end
    ),
    vuln_type: (
      if (.extra.metadata.cwe | type) == "array" then (.extra.metadata.cwe[0] | split(":")[0])
      elif (.extra.metadata.cwe | type) == "string" then (.extra.metadata.cwe | split(":")[0])
      else "CWE-20"
      end
    )
  }
]' "$INPUT_JSON" > "$OUTPUT_JSON"

COUNT=$(jq 'length' "$OUTPUT_JSON")
echo "[+] Converted ${COUNT} Semgrep findings into CodeMender schema at: ${OUTPUT_JSON}"
