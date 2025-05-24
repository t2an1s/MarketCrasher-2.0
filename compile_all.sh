#!/usr/bin/env bash
# Portable: works on macOS Bash 3.2 and Linux Bash 5+
set -u           # NO 'set -e' so we don't abort on first failure
shopt -s nullglob

CX="/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/cxstart"
BOT="MT5"
EXE="C:/Program Files/MetaTrader 5/metaeditor64.exe"
INC="/include:\"$PWD/MQL5/Include\""      # <─ add more /include:"…" if needed

##########################################
# 1. Decide what to compile
##########################################
if [[ $# -gt 0 && -n "$1" ]]; then
  FILES=( "$@" )                          # glob passed from workflow input
else
  # default: every .mq5 anywhere in repo
  mapfile -t FILES < <(find . -type f -name '*.mq5' | sort)
fi

[[ ${#FILES[@]} -gt 0 ]] || { echo "❌ No MQ5 files found"; exit 1; }

##########################################
# 2. Compile loop (never abort early)
##########################################
status=0      # 0 = all good; 1 = any file had errors
summary=$(mktemp)

for src in "${FILES[@]}"; do
  log="${src%.mq5}.log"
  echo "→ Compiling $src"
  "$CX" --bottle "$BOT" --wait -- \
        "$EXE" $INC /compile:"$PWD/$src" /log:"$PWD/$log" || true

  # count errors MetaEditor reports
  errs=$(grep -Eo '([0-9]+) error\(s\)' "$log" | awk '{s+=$1} END{print s+0}')
  printf "%-70s | %3d\n" "$src" "$errs" >> "$summary"
  [[ $errs -eq 0 ]] || status=1
done

##########################################
# 3. Print summary
##########################################
echo -e "\n================ Build summary ================"
printf "%-70s | %s\n" "file" "errors"
printf -- "--------------------------------------------------------------------+-------\n"
cat "$summary"
printf -- "--------------------------------------------------------------------+-------\n"

if [[ $status -eq 0 ]]; then
  echo "✅ All MQ5 sources compiled successfully."
else
  echo "❌ One or more sources failed – check logs above."
fi

exit $status
