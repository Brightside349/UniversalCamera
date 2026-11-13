#!/usr/bin/env bash
# Ejecuta las pruebas headless del Replay.
# Requiere el CLI de Luau en tools/luau.exe (se descarga de
# https://github.com/luau-lang/luau/releases).
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -x tools/luau.exe ]; then
    echo "No está tools/luau.exe. Descarga luau-windows.zip de Luau releases y descomprímelo en tools/." >&2
    exit 1
fi

powershell -NoProfile -ExecutionPolicy Bypass -File tests/gen_sources.ps1
./tools/luau.exe tests/run.lua
