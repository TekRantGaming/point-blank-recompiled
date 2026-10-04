@echo off
rem Double-click to build Point Blank on this PC from your own PlayStation disc.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build-PointBlank.ps1" %*
