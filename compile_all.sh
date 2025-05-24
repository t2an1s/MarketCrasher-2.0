#!/usr/bin/env bash
set -u                               # no ‘-e’ → keep going after errors
shopt -s nullglob

CX="/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/cxstart"
BOT="MT5"
EXE="C:/Program Files/MetaTrader 5/metaeditor64.exe"
INC="/include:\"$PWD/MQL5/Include\""

# -------- choose files -----------------------------------------------------
if [[ $# -gt 0 && -n "$1" ]]; then
  FILES=( "$@" )                     # from workflow input
else
  mapfile -t FILES < <(find . -type f -name '*.mq5' | sort)
fi
[[ ${#FILES[@]} -gt 0 ]] || { echo "❌ no .mq5 files"; exit 1; }
# --------------------------------------------------------------------------

status=0
summary=$(mktemp)

for src in "${FILES[@]}"; do
  log="${src%.mq5}.log"
  mkdir -p "$(dirname "$log")"

  echo "→ compiling $src"
  "$CX" --bottle "$BOT" --wait -- \
        "$EXE" $INC /compile:"$PWD/$src" /log:"$PWD/$log" || true

  errs=$(grep -Eo '([0-9]+) error\(s\)' "$log" | awk '{s+=$1} END{print s+0}')
  printf "%-70s | %3d\n" "$src" "$errs" >> "$summary"
  [[ $errs -eq 0 ]] || status=1
done

echo -e "\n================ build summary ================"
printf "%-70s | %s\n" "file" "errors"
printf -- "--------------------------------------------------------------------+-----\n"
cat "$summary"
printf -- "--------------------------------------------------------------------+-----\n"

[[ $status -eq 0 ]] && echo "✅ all sources compiled" \
                    || echo "❌ one or more sources failed"
exit $status
