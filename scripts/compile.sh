#!/usr/bin/env bash
set -e
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR/.."

MT5_PATH="${1:-${METATRADER_PATH:-/Applications}}"

if [ -z "$MT5_PATH" ]; then
  echo "Usage: METATRADER_PATH=/path/to/MetaTrader ./scripts/compile.sh" >&2
  echo "   or: ./scripts/compile.sh /path/to/MetaTrader" >&2
  exit 1
fi

EXE="$MT5_PATH/metaeditor64.exe"
if [ ! -f "$EXE" ]; then
  echo "metaeditor64.exe not found in $MT5_PATH" >&2
  exit 1
fi

"$EXE" /compile:"MQL5/Experts/PropEA/MasterEA.mq5" /log:"MasterEA.log"
"$EXE" /compile:"MQL5/Experts/PropEA/SlaveEA.mq5" /log:"SlaveEA.log"

