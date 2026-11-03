#!/usr/bin/env bash
set -e
echo "Starting OrbisCRM Global on http://localhost:3000 ..."
if command -v python3 >/dev/null 2>&1; then
  python3 server.py
else
  node server.js
fi
