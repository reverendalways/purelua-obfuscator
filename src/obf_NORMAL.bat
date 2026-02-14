@echo off
if "%~1"=="" (echo Usage: %~nx0 ^<input.lua^> [output.lua] & exit /b 1)
luajit.exe "%~dp0cli.lua" --preset Normal "%~1" "%~2"
pause