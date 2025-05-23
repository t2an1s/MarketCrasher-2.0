# MarketCrasher EA

This repository contains the MetaTrader 5 implementation of the TradingView strategy described in `TradingView PropStrategy .txt`.

Two EAs are provided:

- **MasterEA** – trades the prop account and writes hedge instructions for the slave.
- **SlaveEA** – reads hedge instructions from file and opens opposite trades on a hedge account.

A dashboard implementation is available in `MQL5/Include/Dashboard.mqh`.

Pivot calculations for stop loss and take profit are implemented in
`MQL5/Include/Pivot.mqh`. The EA can optionally draw a zigzag line showing
recent pivot highs and lows on the chart.

Additional modules provide the multi-timeframe synergy score, market bias
oscillator and ADX filter used by the strategy.

Synergy score logic from the TradingView script is implemented in
`MQL5/Include/Synergy.mqh` and used by the MasterEA to filter trades.

## Usage
1. Place the files inside your terminal's `MQL5` directory preserving the folder structure.
2. Compile `MQL5/Experts/PropEA/MasterEA.mq5` and `MQL5/Experts/PropEA/SlaveEA.mq5` in MetaEditor or run the helper script:

   ```sh
   METATRADER_PATH=/path/to/MetaTrader5 ./scripts/compile.sh

   # or pass the path as an argument
   ./scripts/compile.sh /path/to/MetaTrader5
  ```
   The path should point to the folder containing `metaeditor64.exe` from your MetaTrader 5 installation. If no path is provided, the script defaults to `/Applications` which is the typical location on macOS.
3. Attach `MasterEA` to the prop account chart and `SlaveEA` to the hedge account chart.

Adjust the input parameters of both EAs to match your desired risk and strategy settings.
