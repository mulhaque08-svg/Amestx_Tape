@echo off
title TxDOT Estimator Web Server (Port 8081)
echo =========================================================================
echo  Starting Amestx TxDOT Estimator Local Web Server on http://localhost:8081/
echo =========================================================================
echo.
start http://localhost:8081/
powershell -ExecutionPolicy Bypass -File "%~dp0server.ps1" -port 8081
pause
