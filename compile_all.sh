#!/usr/bin/env bash
# compile_all.sh – portable; never aborts early; summary table
# works on macOS Bash 3.2 and Linux Bash 5+

set -u                    # NO “-e” → continue after individual file errors
shopt -s nullglob

CX="/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/cxstart"
BOT="MT5"
EXE="C:/Program Files/MetaTrader 5/metaeditor64.exe"
INC="/include:\"$PWD/MQL5/Include\""          # adjust / add more if needed

##############################################################################
# 1. Decide which MQ5 files to compile
##############################################################################
FILES=()                                  # always initialise

if [[ $# -gt 0 && -n "$1" ]]; then
  # Paths/glob passed from workflow input
  FILES=( "$@" )
else
  # Default: every .mq5 in the repo
  while IFS= read -r -d '' f; do
    FILES+=( "$f" )
  done < <(find . -type f -name '*.mq5' -print0 | sort -z)
fi

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "❌ No MQ5 files found to compile"
  exit 1
fi

##############################################################################
# 2. Compile loop
##############################################################################
status=0
summary=$(mktemp)

for src in "${FILES[@]}"; do
  log="${src%.mq5}.log"
  mkdir -p "$(dirname "$log")"

  echo "→ Compiling $src"
  "$CX" --bottle "$BOT" --wait -- \
        "$EXE" $INC /compile:"$PWD/$src" /log:"$PWD/$log" || true

# count lines that contain ": error " or ": fatal "  (case-insensitive)
  errs=$(grep -iE ': (error|fatal) ' "$log" | wc -l | tr -d ' ')
  printf "%-70s | %3d\n" "$src" "$errs" >> "$summary"
  [[ $errs -eq 0 ]] || status=1
done

##############################################################################
# 3. Summary
##############################################################################
echo -e "\n================ Build summary ================"
printf "%-70s | %s\n" "file" "errors"
printf -- "--------------------------------------------------------------------+-----\n"
cat "$summary"
printf -- "--------------------------------------------------------------------+-----\n"

[[ $status -eq 0 ]] \
  && echo "✅ All MQ5 sources compiled successfully." \
  || echo "❌ One or more sources failed – see logs above."

exit $status
