# MarketCrasher EA

This repository contains the MetaTrader 5 implementation of the TradingView strategy described in `TradingView PropStrategy .txt`.

Two EAs are provided:

- **MasterEA** – trades the prop account and writes hedge instructions for the slave.
- **SlaveEA** – reads hedge instructions from file and opens opposite trades on a hedge account.

A dashboard implementation is available in `MQL5/Include/Dashboard.mqh`.
Synergy score logic from the TradingView script is implemented in
`MQL5/Include/Synergy.mqh` and used by the MasterEA to filter trades.

## Usage
1. Place the files inside your terminal's `MQL5` directory preserving the folder structure.
2. Compile `MQL5/Experts/PropEA/MasterEA.mq5` and `MQL5/Experts/PropEA/SlaveEA.mq5` in MetaEditor.
3. Attach `MasterEA` to the prop account chart and `SlaveEA` to the hedge account chart.

Adjust the input parameters of both EAs to match your desired risk and strategy settings.
