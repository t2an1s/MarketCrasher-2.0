cat > ci-setup.sh <<'EOS'
#!/usr/bin/env bash
# ci-setup.sh — one-time Wine + MetaEditor install for Linux CI containers
set -euo pipefail

# ---- 0. install Wine (minimal) --------------------------------------------
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive \
     apt-get install -y --no-install-recommends \
     wine winbind xvfb unzip curl ca-certificates

# ---- 1. make a fresh 64-bit Wine prefix -----------------------------------
export WINEPREFIX="$HOME/wine-mt5"
wineboot -u >/dev/null 2>&1  || true   # creates dirs; errors are harmless

# ---- 2. download portable MT5 ZIP ( ~70 MB, public mirror ) ---------------
MT5_ZIP_URL="https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe"
curl -L -o /tmp/mt5setup.exe "$MT5_ZIP_URL"

# ---- 3. silent install in C:\Platform -------------------------------------
wine /tmp/mt5setup.exe /silent /dir="C:\\\\Platform" /components=Main,MetaEditor

# ---- 4. export path for downstream steps ----------------------------------
echo "WINEPREFIX=$WINEPREFIX"                                   >> "$GITHUB_ENV"
echo "METAEDITOR_EXE=$WINEPREFIX/drive_c/Platform/metaeditor64.exe" >> "$GITHUB_ENV"
EOS
chmod +x ci-setup.sh
