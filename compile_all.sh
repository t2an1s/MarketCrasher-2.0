#!/usr/bin/env bash
set -euo pipefail

CX="/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/cxstart"
BOT="MT5"
EXE="C:/Program Files/MetaTrader 5/metaeditor64.exe"

# ---------- choose files --------------------------------------------------
if [[ $# -gt 0 && -n "$1" ]]; then           # passed from workflow input
  FILES=( "$@" )
else
  FILES=( MQL5/Experts/PropEA/*.mq5 )        # <-- adjust to your folder
fi
shopt -s nullglob
[[ ${#FILES[@]} -gt 0 ]] || { echo "❌ No MQ5 files found"; exit 1; }
# --------------------------------------------------------------------------

declare -A ERRORS           # filename ➜ error count
status=0

for src in "${FILES[@]}"; do
  log="${src%.mq5}.log"
  echo "→ Compiling $src"

  "$CX" --bottle "$BOT" --wait -- \
        "$EXE" /compile:"$PWD/$src" /log:"$PWD/$log"

  # Count errors in the log
  err_cnt=$(grep -Eo '([0-9]+) error\(s\)' "$log" | awk '{sum+=$1} END{print sum+0}')
  ERRORS["$src"]=$err_cnt

  [[ $err_cnt -eq 0 ]] || status=1
done

echo -e "\n===== Build summary ====="
printf "%-45s | %s\n" "file" "errors"
printf -- "-----------------------------------------------+--------\n"
for f in "${!ERRORS[@]}"; do
  printf "%-45s | %d\n" "$f" "${ERRORS[$f]}"
done
printf -- "-----------------------------------------------+--------\n"

if [[ $status -eq 0 ]]; then
  echo "✅ All MQ5 sources compiled successfully."
else
  echo "❌ One or more sources failed – see logs above."
fi

exit $status
