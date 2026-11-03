@echo off
title OrbisCRM Global Enterprise Platform
echo Starting OrbisCRM Global on http://localhost:3000 ...
start http://localhost:3000
where python >nul 2>nul
if %errorlevel%==0 (
    python server.py
) else (
    node server.js
)
pause
