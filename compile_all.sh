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
