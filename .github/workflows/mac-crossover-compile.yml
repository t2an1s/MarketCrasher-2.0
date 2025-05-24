name: Local Mac – MT5 compile          # shows in the Actions list

on:
  workflow_dispatch:                   # manual “Run workflow” button
    inputs:                            # (optional) compile subset of files
      files:
        description: 'Glob of MQ5 files (blank = *.mq5)'
        required: false
        default: ''

jobs:
  build:
    # labels must match your runner;  macOS is automatic, self-hosted is default
    runs-on: [self-hosted, macOS]

    steps:
      - name: ⬇️  Checkout repo
        uses: actions/checkout@v4

      - name: 🛠️  Compile MQ5 inside CrossOver
        shell: bash
        run: |
          CX="/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/cxstart"
          BOT="MT5"
          EXE="C:/Program Files/MetaTrader 5/metaeditor64.exe"

          # decide which files to build
          shopt -s nullglob
          FILES="${{ github.event.inputs.files }}"
          [[ -z "$FILES" ]] && FILES="*.mq5"

          echo "Files to compile: $FILES"
          status=0

          for src in $FILES; do
            log="${src%.mq5}.log"
            echo "::group::Compiling $src"
            "$CX" --bottle "$BOT" --wait -- \
                  "$EXE" /compile:"$PWD/$src" /log:"$PWD/$log" || status=$?
            cat "$log"                            # show compiler output
            echo "::endgroup::"

            # fail the job if MetaEditor found errors
            grep -q "0 error" "$log" || status=1
          done

          exit $status

      - name: 📦 Upload .log files (always)
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: mq5-logs
          path: '*.log'
