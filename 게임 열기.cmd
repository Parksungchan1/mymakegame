@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo.
echo   Godot 에디터로 게임을 엽니다...
echo.

set "GODOT=%~dp0tools\Godot\Godot.exe"
if exist "%GODOT%" goto :run

rem 예전 무설치 경로들도 찾아본다
for %%P in (
  "%USERPROFILE%\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe"
  "%USERPROFILE%\Downloads\Godot_v4.7.1-stable_win64.exe"
) do (
  if exist %%P (
    set "GODOT=%%~P"
    goto :run
  )
)

where godot >nul 2>nul
if not errorlevel 1 (
  set "GODOT=godot"
  goto :run
)

echo   [!] Godot 을 찾지 못했습니다.
echo       setup.ps1 을 실행하면 tools\Godot\ 에 자동으로 받아둡니다.
echo       powershell -ExecutionPolicy Bypass -File setup.ps1
echo.
pause
exit /b 1

:run
echo   실행: %GODOT%
echo   에디터가 뜨면 F5 를 눌러 플레이하세요.
echo.
start "" "%GODOT%" --path "%~dp0game" --editor
