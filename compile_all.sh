#!/usr/bin/env bash
# compile_all.sh – MT5 CrossOver compiler (macOS Bash 3.2+ / Linux Bash 5+)
# • never aborts after a single file error
# • prints a Δ-free summary table (err / warn counters)
# • shows a coloured excerpt of every error/warning line
# • works no matter where you launch it from
# --------------------------------------------------------------

set -u                      # *no* “-e” → keep looping even on errors
shopt -s globstar nullglob

CX="/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/cxstart"
BOT="MT5"
EXE="C:/Program Files/MetaTrader 5/metaeditor64.exe"
INC="/include:\"$PWD/MQL5/Include\""        # add more -I paths if you need

BUILD_DIR="build_logs"
mkdir -p "$BUILD_DIR"

##############################################################################
# 1. decide which .mq5 to compile
##############################################################################
if [[ $# -gt 0 && -n $1 ]]; then
  # manual glob / list passed from the workflow input
  FILES=( "$@" )
else
  # repo-wide default
  mapfile -t FILES < <(find . -type f -name '*.mq5' | sort)
fi

[[ ${#FILES[@]} -gt 0 ]] || { echo "❌ No MQ5 sources found"; exit 1; }

##############################################################################
# 2. compile loop
##############################################################################
status=0
summary="$(mktemp)"
printf "%-70s | %s | %s\n" "file" "err" "warn" >>"$summary"
printf -- "--------------------------------------------------------------------+-----+-----\n" >>"$summary"

err_re=':[[:space:]]*(error|fatal)'
warn_re=':[[:space:]]*warning'

for src in "${FILES[@]}"; do
  # flat log name:  ./MQL5/Experts/Ea.mq5 → MQL5_Experts_Ea.mq5.log
  flat="${src#./}"
  flat="${flat//[\/ ]/_}"
  log="${BUILD_DIR}/${flat}.log"

  echo "::group::Compiling $src"
  "$CX" --bottle "$BOT" --wait -- \
        "$EXE" $INC /compile:"$PWD/$src" /log:"$PWD/$log" || true

  # error / warning counters
  errs=$(grep -c -i -E "$err_re"  "$log" || true)
  warns=$(grep -c -i -E "$warn_re" "$log" || true)
  printf "%-70s | %3d | %3d\n" "$src" "$errs" "$warns" >>"$summary"
  (( errs == 0 )) || status=1

  # show the first 40 offending lines (if any)
  echo "----- first offending lines (${errs} err, ${warns} warn) in $(basename "$log") -----"
  grep    -i -E "$err_re|$warn_re" "$log" | head -n 40 || echo "<none>"
  echo "----- end excerpt -----"
  echo "::endgroup::"
done

##############################################################################
# 3. build summary
##############################################################################
echo -e "\n================ build summary ==========================="
cat "$summary"
printf -- "--------------------------------------------------------------------+-----+-----\n"

(( status == 0 )) \
  && echo "✅ All sources compiled *without* errors" \
  || echo "❌ Errors were found – scroll up ⬆ or open the artefact zip"

exit $status
