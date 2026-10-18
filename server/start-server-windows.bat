@echo off
setlocal
pushd "%~dp0.."

if not defined PRIMALIS_PORT set "PRIMALIS_PORT=9080"
if not defined PRIMALIS_BIND_ADDRESS set "PRIMALIS_BIND_ADDRESS=127.0.0.1"

if defined GODOT_BIN goto configured_godot
set "GODOT_EXE=godot.exe"
where godot.exe >nul 2>&1
if errorlevel 1 goto godot_missing
goto start_server

:configured_godot
if not exist "%GODOT_BIN%" goto bad_godot_path
set "GODOT_EXE=%GODOT_BIN%"

:start_server
echo Starting Primalis Online headless server.
echo Bind address: %PRIMALIS_BIND_ADDRESS%
echo Port: %PRIMALIS_PORT%
echo Default is loopback only. Do not expose plain WebSocket to the public Internet.
"%GODOT_EXE%" --headless --path "%CD%" --script res://server/server_bootstrap.gd -- --port=%PRIMALIS_PORT% --bind-address=%PRIMALIS_BIND_ADDRESS%
set "SERVER_EXIT=%ERRORLEVEL%"
echo.
echo Primalis Online server stopped with exit code %SERVER_EXIT%.
popd
exit /b %SERVER_EXIT%

:godot_missing
echo Godot 4.4.1 was not found in PATH.
echo Install Godot 4.4.1 or set GODOT_BIN to the full path of godot.exe.
goto startup_error

:bad_godot_path
echo GODOT_BIN does not point to an existing file:
echo %GODOT_BIN%

:startup_error
pause
popd
exit /b 1
