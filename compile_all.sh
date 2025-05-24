#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# compile_all.sh  –  Compile every .mq5 passed on the command line OR, if no
# arguments, compile the default glob below.  Works on macOS Bash 3.2.
# ---------------------------------------------------------------------------
set -euo pipefail

CX="/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/cxstart"
BOT="MT5"
EXE="C:/Program Files/MetaTrader 5/metaeditor64.exe"

# -------- 1. Decide which MQ5 files to build -------------------------------
if [[ $# -gt 0 && -n "$1" ]]; then
  FILES=( "$@" )                           # glob / filenames from workflow input
else
  FILES=( MQL5/Experts/PropEA/*.mq5 )      # <— DEFAULT GLOB -- adjust if needed
fi
shopt -s nullglob
[[ ${#FILES[@]} -gt 0 ]] || { echo "❌ No MQ5 files found"; exit 1; }

# -------- 2. Compile loop ---------------------------------------------------
status=0
summary_file=$(mktemp)     # collect per-file results here

for src in "${FILES[@]}"; do
  log="${src%.mq5}.log"
  echo "→ Compiling $src"

  "$CX" --bottle "$BOT" --wait -- \
        "$EXE" /compile:"$PWD/$src" /log:"$PWD/$log"

  # count errors reported by MetaEditor in this log
  err_cnt=$(grep -Eo '([0-9]+) error\(s\)' "$log" \
            | awk '{sum+=$1} END{print sum+0}')

  printf "%-60s | %d\n" "$src" "$err_cnt" >> "$summary_file"
  [[ $err_cnt -eq 0 ]] || status=1
done

# -------- 3. Print summary --------------------------------------------------
echo -e "\n================ Build summary ================"
printf "%-60s | %s\n" "file" "errors"
printf -- "--------------------------------------------------------------+--------\n"
cat "$summary_file"
printf -- "--------------------------------------------------------------+--------\n"

if [[ $status -eq 0 ]]; then
  echo "✅ All MQ5 sources compiled successfully."
else
  echo "❌ One or more sources failed – see logs above."
fi

exit $status
