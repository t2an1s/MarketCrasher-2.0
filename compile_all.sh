#!/usr/bin/env bash
# compile_all.sh – Bash-3.2 compatible, counts real errors, keeps going
set -u
shopt -s nullglob

CX="/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/cxstart"
BOT="MT5"
EXE="C:/Program Files/MetaTrader 5/metaeditor64.exe"
INC="/include:\"$PWD/MQL5/Include\""

LOG_DIR="build_logs"            # <── all logs end up here
mkdir -p "$LOG_DIR"

##############################################################################
# 1. pick files
##############################################################################
FILES=()
if [[ $# -gt 0 && -n "$1" ]]; then
  FILES=( "$@" )
else
  while IFS= read -r -d '' f; do FILES+=( "$f" ); done \
    < <(find . -type f -name '*.mq5' -print0 | sort -z)
fi
[[ ${#FILES[@]} -gt 0 ]] || { echo "❌ no MQ5 files"; exit 1; }

##############################################################################
# 2. compile loop
##############################################################################
status=0
summary=$(mktemp)

for src in "${FILES[@]}"; do
  log="${LOG_DIR}/${src//[\/ ]/_}.log"
  mkdir -p "$(dirname "$log")"

  echo "::group::Compiling $src"
  "$CX" --bottle "$BOT" --wait -- \
        "$EXE" $INC /compile:"$PWD/$src" /log:"$PWD/$log" || true
  echo "::endgroup::"

  # ── count errors & emit annotations ───────────────────────────────
  errs=0
  while IFS= read -r line; do
    if [[ $line =~ :[[:space:]]+(fatal[[:space:]]+)?error[[:space:]] ]]; then
      errs=$((errs+1))
      # best-effort extract file, line, col, message
      if [[ $line =~ ([^:]+):([0-9]+):([0-9]+):[[:space:]]+(.*) ]]; then
        f=${BASH_REMATCH[1]#./}; ln=${BASH_REMATCH[2]}; col=${BASH_REMATCH[3]}; msg=${BASH_REMATCH[4]}
        echo "::error file=$f,line=$ln,col=$col::$msg"
      else
        echo "::error::$line"
      fi
    fi
  done < "$log"

  warns=$(grep -iE ':\s+warning\s+' "$log" | wc -l | tr -d ' ')
  printf "%-60s | %3d | %3d\n" "$src" "$errs" "$warns" >> "$summary"
  [[ $errs -eq 0 ]] || status=1
done
##############################################################################
# 3. summary
##############################################################################
echo -e "\n================ build summary ============================="
printf "%-60s | %s | %s\n" "file" "err" "warn"
printf -- "------------------------------------------------------------+-----+-----\n"
cat "$summary"
printf -- "------------------------------------------------------------+-----+-----\n"

[[ $status -eq 0 ]] \
  && echo "✅ all sources compiled with 0 errors" \
  || echo "❌ one or more sources failed – see $LOG_DIR/*.log"

exit $status
