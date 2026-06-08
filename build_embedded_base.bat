@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0build_embedded_base.ps1" %*
