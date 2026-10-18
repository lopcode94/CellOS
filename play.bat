@echo off
rem Launches Symbio-Shack with the portable Godot in %USERPROFILE%\Godot
start "" "%USERPROFILE%\Godot\Godot_v4.7.2-stable_win64.exe" --path "%~dp0."
