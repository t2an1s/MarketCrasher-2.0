# MarketCrasher EA

This repository contains the MetaTrader 5 implementation of the TradingView strategy described in `TradingView PropStrategy .txt`.

Two EAs are provided:

- **MasterEA** – trades the prop account and writes hedge instructions for the slave.
- **SlaveEA** – reads hedge instructions from file and opens opposite trades on a hedge account.

A dashboard implementation is available in `MQL5/Include/Dashboard.mqh`.
The hedge engine logic is contained in `MQL5/Include/HedgeEngine.mqh` and
provides cost‑recovery sizing, daily drawdown checks and optional hedge
bleeding when 70 % of the stage target is reached.

## Usage
1. Place the files inside your terminal's `MQL5` directory preserving the folder structure.
2. Compile `MQL5/Experts/PropEA/MasterEA.mq5` and `MQL5/Experts/PropEA/SlaveEA.mq5` in MetaEditor.
3. Attach `MasterEA` to the prop account chart and `SlaveEA` to the hedge account chart.

Adjust the input parameters of both EAs to match your desired risk and strategy settings.
Important hedge settings such as challenge fee, drawdown caps and stage
target can be configured in `MasterEA` inputs.
