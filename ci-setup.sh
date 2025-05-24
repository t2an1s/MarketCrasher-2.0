#!/usr/bin/env bash
set -euo pipefail

# 0. update & install wine
sudo apt-get update
sudo apt-get install -y --no-install-recommends wine winbind xvfb unzip

# 1. create a 64-bit Wine prefix
export WINEPREFIX="$HOME/wine-mt5"
wineboot -u  >/dev/null 2>&1

# 2. download portable MT5 (≈ 70 MB)
MT5_URL="https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe"
curl -L -o /tmp/mt5setup.exe "$MT5_URL"

# 3. silent install into the prefix’s C:\Platform
wine /tmp/mt5setup.exe /silent /dir="C:\\Platform" /components=Main,MetaEditor

# 4. remember path for later
echo "METAEDITOR_EXE=$WINEPREFIX/drive_c/Platform/metaeditor64.exe" >> $GITHUB_ENV
echo "WINEPREFIX=$WINEPREFIX"                                         >> $GITHUB_ENV
